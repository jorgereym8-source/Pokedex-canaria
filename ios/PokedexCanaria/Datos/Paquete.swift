import Foundation

/// Lee las fichas empaquetadas dentro de la app (Datos/fichas.pack + Datos/fichas.idx),
/// que genera scripts/empaquetar_datos.py al compilar.
final class PaqueteFichas {
    private struct IndicePaquete: Decodable {
        let formato: Int
        let compresion: String
        let fichas: [String: [Int]]
    }

    private let datos: Data
    private let entradas: [String: [Int]]
    private let comprimido: Bool

    var cuantas: Int { entradas.count }
    var codigos: Dictionary<String, [Int]>.Keys { entradas.keys }

    init?(carpeta: URL) {
        let pack = carpeta.appendingPathComponent("fichas.pack")
        let idx = carpeta.appendingPathComponent("fichas.idx")
        guard let d = try? Data(contentsOf: pack, options: .alwaysMapped),
              let i = try? Data(contentsOf: idx),
              let indice = try? JSONDecoder().decode(IndicePaquete.self, from: i) else { return nil }
        datos = d
        entradas = indice.fichas
        comprimido = indice.compresion == "deflate"
    }

    func contiene(_ codigo: String) -> Bool { entradas[codigo] != nil }

    /// JSON de la ficha (descomprimido)
    func ficha(_ codigo: String) -> Data? {
        guard let e = entradas[codigo], e.count >= 2 else { return nil }
        let inicio = e[0], largo = e[1]
        guard inicio >= 0, largo > 0, inicio + largo <= datos.count else { return nil }
        let trozo = datos.subdata(in: inicio..<(inicio + largo))
        return comprimido ? PaqueteFichas.inflar(trozo) : trozo
    }

    /// DEFLATE sin cabecera → bytes
    static func inflar(_ d: Data) -> Data? {
        #if canImport(Darwin)
        if let r = try? (d as NSData).decompressed(using: .zlib) as Data { return r }
        // Por si el bloque llevara cabecera zlib (2 bytes)
        if d.count > 2, let r = try? (d.dropFirst(2) as NSData).decompressed(using: .zlib) as Data { return r }
        return nil
        #else
        return nil
        #endif
    }
}
