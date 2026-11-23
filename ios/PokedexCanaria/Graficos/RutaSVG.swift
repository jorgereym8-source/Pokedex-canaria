import Foundation

/// Tramo de un trazado ya resuelto a coordenadas absolutas
enum TramoSVG: Equatable {
    case mover(Double, Double)
    case linea(Double, Double)
    case cuadratica(Double, Double, Double, Double)                   // control, destino
    case cubica(Double, Double, Double, Double, Double, Double)       // control 1, control 2, destino
    case cerrar
}

/// Lee el atributo «d» de un <path> de SVG (M L H V C S Q T A Z, absolutos y relativos)
/// y lo convierte en tramos absolutos. Los arcos se convierten en curvas cúbicas.
enum RutaSVG {
    private static var cache: [String: [TramoSVG]] = [:]
    private static let cerrojo = NSLock()

    static func tramos(_ d: String) -> [TramoSVG] {
        cerrojo.lock()
        if let t = cache[d] { cerrojo.unlock(); return t }
        cerrojo.unlock()
        let t = analizar(d)
        cerrojo.lock()
        cache[d] = t
        cerrojo.unlock()
        return t
    }

    private struct Lector {
        let c: [UInt8]
        var i = 0

        init(_ s: String) { c = Array(s.utf8) }

        mutating func saltar() {
            while i < c.count {
                let x = c[i]
                if x == 0x20 || x == 0x2C || x == 0x0A || x == 0x0D || x == 0x09 { i += 1 } else { break }
            }
        }

        /// ¿Hay un número a continuación?
        mutating func hayNumero() -> Bool {
            saltar()
            guard i < c.count else { return false }
            let x = c[i]
            return (x >= 0x30 && x <= 0x39) || x == 0x2D || x == 0x2B || x == 0x2E
        }

        mutating func comando() -> UInt8? {
            saltar()
            guard i < c.count else { return nil }
            let x = c[i]
            if (x >= 0x41 && x <= 0x5A) || (x >= 0x61 && x <= 0x7A), x != 0x65, x != 0x45 {
                i += 1
                return x
            }
            return nil
        }

        mutating func numero() -> Double? {
            saltar()
            guard i < c.count else { return nil }
            let inicio = i
            if c[i] == 0x2D || c[i] == 0x2B { i += 1 }
            var punto = false, digitos = false
            while i < c.count {
                let x = c[i]
                if x >= 0x30 && x <= 0x39 { digitos = true; i += 1 } else if x == 0x2E && !punto { punto = true; i += 1 } else { break }
            }
            // exponente
            if i < c.count, c[i] == 0x65 || c[i] == 0x45 {
                var j = i + 1
                if j < c.count, c[j] == 0x2D || c[j] == 0x2B { j += 1 }
                if j < c.count, c[j] >= 0x30 && c[j] <= 0x39 {
                    i = j
                    while i < c.count, c[i] >= 0x30 && c[i] <= 0x39 { i += 1 }
                }
            }
            guard digitos, let s = String(bytes: c[inicio..<i], encoding: .ascii), let d = Double(s) else {
                i = inicio
                return nil
            }
            return d
        }

        /// Bandera de un arco: un solo carácter 0 o 1 (pueden ir pegadas: «a1 1 0 01 1 1»)
        mutating func bandera() -> Bool? {
            saltar()
            guard i < c.count else { return nil }
            if c[i] == 0x30 { i += 1; return false }
            if c[i] == 0x31 { i += 1; return true }
            return nil
        }
    }

    static func analizar(_ d: String) -> [TramoSVG] { analizarConControl(d).tramos }

    /// Devuelve también si se ha leído el trazado entero (para comprobar los dibujos)
    static func analizarConControl(_ d: String) -> (tramos: [TramoSVG], completo: Bool) {
        var l = Lector(d)
        var out: [TramoSVG] = []
        var x = 0.0, y = 0.0          // punto actual
        var sx = 0.0, sy = 0.0        // inicio del subtrazado
        var cx = 0.0, cy = 0.0        // último punto de control (para S y T)
        var ultimo: UInt8 = 0
        var cmd: UInt8 = 0

        while true {
            if let nuevo = l.comando() {
                cmd = nuevo
            } else if cmd == 0 || !l.hayNumero() {
                break
            }
            let rel = cmd >= 0x61
            let k = rel ? cmd - 0x20 : cmd
            switch k {
            case 0x4D: // M
                guard let a = l.numero(), let b = l.numero() else { return (out, false) }
                x = rel ? x + a : a; y = rel ? y + b : b
                sx = x; sy = y
                out.append(.mover(x, y))
                // los pares siguientes son líneas
                cmd = rel ? 0x6C : 0x4C
                ultimo = 0x4D
                continue
            case 0x4C: // L
                guard let a = l.numero(), let b = l.numero() else { return (out, false) }
                x = rel ? x + a : a; y = rel ? y + b : b
                out.append(.linea(x, y))
            case 0x48: // H
                guard let a = l.numero() else { return (out, false) }
                x = rel ? x + a : a
                out.append(.linea(x, y))
            case 0x56: // V
                guard let b = l.numero() else { return (out, false) }
                y = rel ? y + b : b
                out.append(.linea(x, y))
            case 0x43: // C
                guard let x1 = l.numero(), let y1 = l.numero(), let x2 = l.numero(), let y2 = l.numero(), let a = l.numero(), let b = l.numero() else { return (out, false) }
                let p1x = rel ? x + x1 : x1, p1y = rel ? y + y1 : y1
                let p2x = rel ? x + x2 : x2, p2y = rel ? y + y2 : y2
                x = rel ? x + a : a; y = rel ? y + b : b
                out.append(.cubica(p1x, p1y, p2x, p2y, x, y))
                cx = p2x; cy = p2y
            case 0x53: // S
                guard let x2 = l.numero(), let y2 = l.numero(), let a = l.numero(), let b = l.numero() else { return (out, false) }
                var p1x = x, p1y = y
                if ultimo == 0x43 || ultimo == 0x53 { p1x = 2 * x - cx; p1y = 2 * y - cy }
                let p2x = rel ? x + x2 : x2, p2y = rel ? y + y2 : y2
                x = rel ? x + a : a; y = rel ? y + b : b
                out.append(.cubica(p1x, p1y, p2x, p2y, x, y))
                cx = p2x; cy = p2y
            case 0x51: // Q
                guard let x1 = l.numero(), let y1 = l.numero(), let a = l.numero(), let b = l.numero() else { return (out, false) }
                let p1x = rel ? x + x1 : x1, p1y = rel ? y + y1 : y1
                x = rel ? x + a : a; y = rel ? y + b : b
                out.append(.cuadratica(p1x, p1y, x, y))
                cx = p1x; cy = p1y
            case 0x54: // T
                guard let a = l.numero(), let b = l.numero() else { return (out, false) }
                var p1x = x, p1y = y
                if ultimo == 0x51 || ultimo == 0x54 { p1x = 2 * x - cx; p1y = 2 * y - cy }
                x = rel ? x + a : a; y = rel ? y + b : b
                out.append(.cuadratica(p1x, p1y, x, y))
                cx = p1x; cy = p1y
            case 0x41: // A
                guard let rx = l.numero(), let ry = l.numero(), let rot = l.numero(),
                      let grande = l.bandera(), let horario = l.bandera(),
                      let a = l.numero(), let b = l.numero() else { return (out, false) }
                let nx = rel ? x + a : a, ny = rel ? y + b : b
                out.append(contentsOf: arco(desde: (x, y), hasta: (nx, ny), rx: rx, ry: ry, rotacion: rot, grande: grande, horario: horario))
                x = nx; y = ny
            case 0x5A: // Z
                out.append(.cerrar)
                x = sx; y = sy
                ultimo = k
                cmd = 0
                continue
            default:
                return (out, false)
            }
            ultimo = k
        }
        l.saltar()
        return (out, l.i >= l.c.count)
    }

    /// Arco elíptico (parametrización por extremos de SVG) → curvas cúbicas
    static func arco(desde p0: (Double, Double), hasta p1: (Double, Double), rx rx0: Double, ry ry0: Double,
                     rotacion: Double, grande: Bool, horario: Bool) -> [TramoSVG] {
        var rx = abs(rx0), ry = abs(ry0)
        let (x1, y1) = p0, (x2, y2) = p1
        if (x1 == x2 && y1 == y2) { return [] }
        if rx == 0 || ry == 0 { return [.linea(x2, y2)] }
        let fi = rotacion * .pi / 180
        let cosFi = cos(fi), sinFi = sin(fi)
        let dx = (x1 - x2) / 2, dy = (y1 - y2) / 2
        let x1p = cosFi * dx + sinFi * dy
        let y1p = -sinFi * dx + cosFi * dy
        // corregir radios demasiado pequeños
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = lambda.squareRoot(); rx *= s; ry *= s }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : (max(0, num / den)).squareRoot()
        if grande == horario { coef = -coef }
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)
        let cx = cosFi * cxp - sinFi * cyp + (x1 + x2) / 2
        let cy = sinFi * cxp + cosFi * cyp + (y1 + y2) / 2

        func angulo(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let t1 = angulo(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dt = angulo((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !horario && dt > 0 { dt -= 2 * .pi } else if horario && dt < 0 { dt += 2 * .pi }

        let n = max(1, Int((abs(dt) / (.pi / 2)).rounded(.up)))
        let paso = dt / Double(n)
        let k = 4.0 / 3.0 * tan(paso / 4)
        var out: [TramoSVG] = []
        var t = t1
        for _ in 0..<n {
            let c1 = cos(t), s1 = sin(t)
            let t2 = t + paso
            let c2 = cos(t2), s2 = sin(t2)
            // puntos en la elipse sin rotar, centrada en el origen
            let e1x = rx * (c1 - k * s1), e1y = ry * (s1 + k * c1)
            let e2x = rx * (c2 + k * s2), e2y = ry * (s2 - k * c2)
            let ex = rx * c2, ey = ry * s2
            func g(_ px: Double, _ py: Double) -> (Double, Double) {
                (cosFi * px - sinFi * py + cx, sinFi * px + cosFi * py + cy)
            }
            let a = g(e1x, e1y), b = g(e2x, e2y), e = g(ex, ey)
            out.append(.cubica(a.0, a.1, b.0, b.1, e.0, e.1))
            t = t2
        }
        // fijar el final exacto
        if case .cubica(let a, let b, let c, let d, _, _) = out.last {
            out[out.count - 1] = .cubica(a, b, c, d, x2, y2)
        }
        return out
    }
}
