import Foundation

/// Valor JSON que conserva el orden de las claves de cada objeto.
/// Las fichas se muestran en el mismo orden que en la web (taxonomía, catálogos, secciones de Centinela…),
/// y JSONDecoder no garantiza ese orden; por eso las fichas se leen con este lector.
enum JSON {
    case nulo
    case bool(Bool)
    case num(Double)
    case str(String)
    case arr([JSON])
    case obj([(String, JSON)])

    subscript(_ clave: String) -> JSON? {
        if case .obj(let pares) = self {
            for (k, v) in pares where k == clave { return v }
        }
        return nil
    }

    var texto: String? {
        if case .str(let s) = self { return s }
        if case .num(let d) = self { return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d) }
        return nil
    }
    /// Texto no vacío (o nil)
    var textoNoVacio: String? {
        guard let t = texto?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
    var numero: Double? {
        if case .num(let d) = self { return d }
        if case .str(let s) = self { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
    var entero: Int? {
        guard let d = numero, d.isFinite, abs(d) < 9e15 else { return nil }
        return Int(d.rounded())
    }
    var logico: Bool? {
        if case .bool(let b) = self { return b }
        if case .num(let d) = self { return d != 0 }
        return nil
    }
    var lista: [JSON] {
        if case .arr(let l) = self { return l }
        return []
    }
    var pares: [(String, JSON)] {
        if case .obj(let p) = self { return p }
        return []
    }
    var esNulo: Bool {
        if case .nulo = self { return true }
        return false
    }
    var esObjeto: Bool {
        if case .obj = self { return true }
        return false
    }
    /// Lista de textos (ignora lo que no sea texto)
    var textos: [String] { lista.compactMap { $0.texto } }
}

enum ErrorJSON: Error, LocalizedError {
    case inesperado(Int)
    case fin

    var errorDescription: String? {
        switch self {
        case .inesperado(let p): return "JSON no válido (posición \(p))"
        case .fin: return "JSON incompleto"
        }
    }
}

/// Lector de JSON sencillo y rápido sobre bytes UTF-8.
struct LectorJSON {
    private let b: [UInt8]
    private var i = 0

    private init(_ bytes: [UInt8]) { b = bytes }

    static func leer(_ datos: Data) throws -> JSON {
        var l = LectorJSON([UInt8](datos))
        // BOM UTF-8
        if l.b.count >= 3, l.b[0] == 0xEF, l.b[1] == 0xBB, l.b[2] == 0xBF { l.i = 3 }
        l.espacios()
        let v = try l.valor()
        l.espacios()
        if l.i != l.b.count { throw ErrorJSON.inesperado(l.i) }
        return v
    }

    private mutating func espacios() {
        while i < b.count {
            let c = b[i]
            if c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 { i += 1 } else { break }
        }
    }

    private mutating func valor() throws -> JSON {
        guard i < b.count else { throw ErrorJSON.fin }
        switch b[i] {
        case 0x7B: return try objeto()          // {
        case 0x5B: return try lista()           // [
        case 0x22: return .str(try cadena())    // "
        case 0x74: try literal([0x74, 0x72, 0x75, 0x65]); return .bool(true)          // true
        case 0x66: try literal([0x66, 0x61, 0x6C, 0x73, 0x65]); return .bool(false)   // false
        case 0x6E: try literal([0x6E, 0x75, 0x6C, 0x6C]); return .nulo                // null
        default: return .num(try numero())
        }
    }

    private mutating func literal(_ l: [UInt8]) throws {
        guard i + l.count <= b.count else { throw ErrorJSON.fin }
        for (k, c) in l.enumerated() where b[i + k] != c { throw ErrorJSON.inesperado(i + k) }
        i += l.count
    }

    private mutating func objeto() throws -> JSON {
        i += 1 // {
        var pares: [(String, JSON)] = []
        espacios()
        if i < b.count, b[i] == 0x7D { i += 1; return .obj(pares) }
        while true {
            espacios()
            guard i < b.count else { throw ErrorJSON.fin }
            guard b[i] == 0x22 else { throw ErrorJSON.inesperado(i) }
            let clave = try cadena()
            espacios()
            guard i < b.count else { throw ErrorJSON.fin }
            guard b[i] == 0x3A else { throw ErrorJSON.inesperado(i) } // :
            i += 1
            espacios()
            let v = try valor()
            pares.append((clave, v))
            espacios()
            guard i < b.count else { throw ErrorJSON.fin }
            if b[i] == 0x2C { i += 1; continue }        // ,
            if b[i] == 0x7D { i += 1; return .obj(pares) } // }
            throw ErrorJSON.inesperado(i)
        }
    }

    private mutating func lista() throws -> JSON {
        i += 1 // [
        var l: [JSON] = []
        espacios()
        if i < b.count, b[i] == 0x5D { i += 1; return .arr(l) }
        while true {
            espacios()
            l.append(try valor())
            espacios()
            guard i < b.count else { throw ErrorJSON.fin }
            if b[i] == 0x2C { i += 1; continue }
            if b[i] == 0x5D { i += 1; return .arr(l) }
            throw ErrorJSON.inesperado(i)
        }
    }

    private mutating func numero() throws -> Double {
        let inicio = i
        while i < b.count {
            let c = b[i]
            // 0-9 + - . e E
            if (c >= 0x30 && c <= 0x39) || c == 0x2B || c == 0x2D || c == 0x2E || c == 0x65 || c == 0x45 { i += 1 } else { break }
        }
        guard i > inicio, let s = String(bytes: b[inicio..<i], encoding: .ascii), let d = Double(s) else {
            throw ErrorJSON.inesperado(inicio)
        }
        return d
    }

    private mutating func cadena() throws -> String {
        i += 1 // comilla de apertura
        let inicio = i
        // Camino rápido: sin escapes
        while i < b.count {
            let c = b[i]
            if c == 0x22 {
                let s = String(decoding: b[inicio..<i], as: UTF8.self)
                i += 1
                return s
            }
            if c == 0x5C { break }
            i += 1
        }
        guard i < b.count else { throw ErrorJSON.fin }
        // Con escapes
        var buf = [UInt8](b[inicio..<i])
        while i < b.count {
            let c = b[i]
            if c == 0x22 {
                i += 1
                return String(decoding: buf, as: UTF8.self)
            }
            if c == 0x5C {
                i += 1
                guard i < b.count else { throw ErrorJSON.fin }
                let e = b[i]
                i += 1
                switch e {
                case 0x22: buf.append(0x22)
                case 0x5C: buf.append(0x5C)
                case 0x2F: buf.append(0x2F)
                case 0x62: buf.append(0x08)
                case 0x66: buf.append(0x0C)
                case 0x6E: buf.append(0x0A)
                case 0x72: buf.append(0x0D)
                case 0x74: buf.append(0x09)
                case 0x75: // \uXXXX
                    var cp = try hex4()
                    if cp >= 0xD800 && cp <= 0xDBFF {
                        // par sustituto
                        if i + 1 < b.count, b[i] == 0x5C, b[i + 1] == 0x75 {
                            i += 2
                            let bajo = try hex4()
                            if bajo >= 0xDC00 && bajo <= 0xDFFF {
                                cp = 0x10000 + ((cp - 0xD800) << 10) + (bajo - 0xDC00)
                            } else {
                                cp = 0xFFFD
                            }
                        } else {
                            cp = 0xFFFD
                        }
                    } else if cp >= 0xDC00 && cp <= 0xDFFF {
                        cp = 0xFFFD
                    }
                    utf8(cp, en: &buf)
                default:
                    throw ErrorJSON.inesperado(i - 1)
                }
                continue
            }
            buf.append(c)
            i += 1
        }
        throw ErrorJSON.fin
    }

    private mutating func hex4() throws -> UInt32 {
        guard i + 4 <= b.count else { throw ErrorJSON.fin }
        var v: UInt32 = 0
        for _ in 0..<4 {
            let c = b[i]
            var d: UInt32
            switch c {
            case 0x30...0x39: d = UInt32(c - 0x30)
            case 0x41...0x46: d = UInt32(c - 0x41 + 10)
            case 0x61...0x66: d = UInt32(c - 0x61 + 10)
            default: throw ErrorJSON.inesperado(i)
            }
            v = v * 16 + d
            i += 1
        }
        return v
    }

    private func utf8(_ cp: UInt32, en buf: inout [UInt8]) {
        switch cp {
        case 0..<0x80:
            buf.append(UInt8(cp))
        case 0x80..<0x800:
            buf.append(UInt8(0xC0 | (cp >> 6)))
            buf.append(UInt8(0x80 | (cp & 0x3F)))
        case 0x800..<0x10000:
            buf.append(UInt8(0xE0 | (cp >> 12)))
            buf.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
            buf.append(UInt8(0x80 | (cp & 0x3F)))
        default:
            buf.append(UInt8(0xF0 | (cp >> 18)))
            buf.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
            buf.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
            buf.append(UInt8(0x80 | (cp & 0x3F)))
        }
    }
}
