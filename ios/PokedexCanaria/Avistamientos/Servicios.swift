import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Consultas a servicios externos: Nominatim (OpenStreetMap), Open-Meteo e iNaturalist
enum Servicios {
    static let sesion: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.httpAdditionalHeaders = ["User-Agent": "PokedexCanaria/1.0 (app personal para iPhone)", "Accept": "application/json"]
        return URLSession(configuration: c)
    }()

    static func json(_ url: URL) async throws -> [String: Any] {
        let (d, r) = try await sesion.data(from: url)
        guard (r as? HTTPURLResponse)?.statusCode == 200, let o = try JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }
        return o
    }

    // MARK: - Lugar

    /// Municipio y paraje más cercano (OpenStreetMap · Nominatim)
    static func nombreLugar(lat: Double, lon: Double) async throws -> (municipio: String, paraje: String) {
        let u = URL(string: "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=\(lat)&lon=\(lon)&zoom=16&accept-language=es")!
        let j = try await json(u)
        let a = j["address"] as? [String: Any] ?? [:]
        func primero(_ ks: [String]) -> String {
            for k in ks { if let s = a[k] as? String, !s.isEmpty { return s } }
            return ""
        }
        let municipio = primero(["city", "town", "village", "municipality", "county"])
        let paraje = primero(["hamlet", "suburb", "neighbourhood", "locality", "isolated_dwelling", "natural", "peak", "road"])
        return (municipio, paraje == municipio ? "" : paraje)
    }

    /// Altitud del modelo del terreno (Open-Meteo)
    static func altitud(lat: Double, lon: Double) async throws -> Double? {
        let j = try await json(URL(string: "https://api.open-meteo.com/v1/elevation?latitude=\(lat)&longitude=\(lon)")!)
        if let l = j["elevation"] as? [Any], let x = l.first as? NSNumber { return x.doubleValue.rounded() }
        return nil
    }

    // MARK: - Tiempo

    static func tiempoAhora(lat: Double, lon: Double) async throws -> TiempoAv {
        let j = try await json(URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=\(Meteo.variables)&timezone=auto")!)
        guard let c = j["current"] as? [String: Any] else { throw URLError(.cannotParseResponse) }
        return Meteo.empaquetar(c)
    }

    /// Tiempo de una hora pasada (para avistamientos guardados sin conexión)
    static func tiempoEn(lat: Double, lon: Double, fecha: Date) async throws -> TiempoAv {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour], from: fecha)
        let dia = String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
        let urls = [
            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&hourly=\(Meteo.variables)&start_date=\(dia)&end_date=\(dia)&timezone=UTC",
            "https://archive-api.open-meteo.com/v1/archive?latitude=\(lat)&longitude=\(lon)&hourly=\(Meteo.variables)&start_date=\(dia)&end_date=\(dia)&timezone=UTC",
        ]
        for s in urls {
            guard let u = URL(string: s), let j = try? await json(u), let h = j["hourly"] as? [String: Any],
                  let horas = h["time"] as? [String] else { continue }
            guard let i = horas.firstIndex(where: { Int($0.dropFirst(11).prefix(2)) == c.hour }) else { continue }
            var o: [String: Any] = [:]
            for (k, v) in h { if let l = v as? [Any], i < l.count { o[k] = l[i] } }
            guard o["temperature_2m"] is NSNumber else { continue }
            var t = Meteo.empaquetar(o)
            t.historico = true
            return t
        }
        throw URLError(.resourceUnavailable)
    }

    // MARK: - Calendario (iNaturalist)

    struct Fenologia: Codable {
        var total: [Int]
        var flor: [Int]
        var fruto: [Int]
        var n: Int
        var especie: Bool
    }

    private static func carpetaCache() -> URL {
        let c = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        let u = c.appendingPathComponent("fenologia", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Observaciones verificables por mes en Canarias (con floración y frutos si es una planta). Se guarda 30 días.
    static func fenologia(nombre: String, codigo: String, flora: Bool) async throws -> Fenologia {
        let archivo = carpetaCache().appendingPathComponent("\(codigo).json")
        if let at = try? FileManager.default.attributesOfItem(atPath: archivo.path), let m = at[.modificationDate] as? Date,
           Date().timeIntervalSince(m) < 30 * 86400, let d = try? Data(contentsOf: archivo),
           let f = try? JSONDecoder().decode(Fenologia.self, from: d) {
            return f
        }
        let partes = nombre.split(separator: " ").map(String.init).filter { !Cat.rangos.contains($0) }
        let binomio = partes.prefix(2).joined(separator: " ")
        var permitidos = CharacterSet.urlQueryAllowed
        permitidos.remove(charactersIn: "&=+")
        let q = binomio.addingPercentEncoding(withAllowedCharacters: permitidos) ?? binomio
        let base = "https://api.inaturalist.org/v1/observations/histogram?taxon_name=\(q)&swlat=27.4&swlng=-18.4&nelat=29.6&nelng=-13.2&interval=month_of_year&date_field=observed&verifiable=true"
        @Sendable func leer(_ s: String) async throws -> [Int] {
            let j = try await json(URL(string: s)!)
            let r = (j["results"] as? [String: Any])?["month_of_year"] as? [String: Any] ?? [:]
            return (1...12).map { (r[String($0)] as? NSNumber)?.intValue ?? 0 }
        }
        let total = try await leer(base)
        var flor = Array(repeating: 0, count: 12), fruto = Array(repeating: 0, count: 12)
        if flora {
            async let f = leer(base + "&term_id=12&term_value_id=13")
            async let r = leer(base + "&term_id=12&term_value_id=14")
            flor = (try? await f) ?? flor
            fruto = (try? await r) ?? fruto
        }
        let res = Fenologia(total: total, flor: flor, fruto: fruto, n: total.reduce(0, +), especie: partes.count > 2)
        if let d = try? JSONEncoder().encode(res) { try? d.write(to: archivo, options: .atomic) }
        return res
    }
}
