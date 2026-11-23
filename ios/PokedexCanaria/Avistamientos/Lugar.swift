import Foundation

/// Datos del tiempo de un avistamiento (Open-Meteo)
struct TiempoAv: Codable, Equatable {
    var temperatura: Double?
    var humedad: Double?
    var lluvia: Double?
    var nubosidad: Double?
    var viento: Double?
    var direccion: Double?
    var codigo: Int?
    var fuente: String? = "Open-Meteo"
    var hora: String?
    var historico: Bool?

    /// Resumen de una línea: 21 °C · Despejado · viento 12 km/h NE · humedad 60 % · lluvia 0 mm
    var resumen: String? {
        guard let t = temperatura else { return nil }
        var p = ["\(Int(t.rounded())) °C"]
        if let c = codigo { p.append(Meteo.cielo(c).0) }
        if let v = viento { p.append("viento \(Int(v.rounded())) km/h \(Meteo.rumbo(direccion))".trimmingCharacters(in: .whitespaces)) }
        if let h = humedad { p.append("humedad \(decimal(h, 0)) %") }
        if let l = lluvia { p.append("lluvia \(decimal(l, 1)) mm") }
        return p.joined(separator: " · ")
    }
}

enum Meteo {
    /// Códigos WMO → (descripción, icono)
    static let wmo: [Int: (String, String)] = [
        0: ("Despejado", "sol"), 1: ("Casi despejado", "sol"), 2: ("Parcialmente nuboso", "nubesol"), 3: ("Cubierto", "nube"),
        45: ("Niebla", "niebla"), 48: ("Niebla con escarcha", "niebla"), 51: ("Llovizna débil", "lluvia"), 53: ("Llovizna", "lluvia"),
        55: ("Llovizna intensa", "lluvia"), 61: ("Lluvia débil", "lluvia"), 63: ("Lluvia", "lluvia"), 65: ("Lluvia fuerte", "lluvia"),
        71: ("Nieve débil", "nieve"), 73: ("Nieve", "nieve"), 75: ("Nieve fuerte", "nieve"), 80: ("Chubascos débiles", "lluvia"),
        81: ("Chubascos", "lluvia"), 82: ("Chubascos fuertes", "lluvia"), 95: ("Tormenta", "tormenta"), 96: ("Tormenta con granizo", "tormenta"),
        99: ("Tormenta con granizo", "tormenta"),
    ]
    static func cielo(_ c: Int?) -> (String, String) {
        guard let c else { return ("—", "nube") }
        return wmo[c] ?? ("—", "nube")
    }

    static let rumbos = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
    static func rumbo(_ g: Double?) -> String {
        guard let g else { return "" }
        let x = g.truncatingRemainder(dividingBy: 360)
        let i = Int((x / 45).rounded()) % 8
        return rumbos[(i + 8) % 8]
    }

    static let variables = "temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,wind_direction_10m,weather_code"

    static func empaquetar(_ o: [String: Any]) -> TiempoAv {
        func d(_ k: String) -> Double? { (o[k] as? NSNumber)?.doubleValue }
        return TiempoAv(temperatura: d("temperature_2m"), humedad: d("relative_humidity_2m"), lluvia: d("precipitation"),
                        nubosidad: d("cloud_cover"), viento: d("wind_speed_10m"), direccion: d("wind_direction_10m"),
                        codigo: d("weather_code").map { Int($0) }, fuente: "Open-Meteo", hora: o["time"] as? String, historico: nil)
    }
}

enum Lugar {
    /// Isla aproximada por rectángulos (funciona sin conexión). Los islotes van primero.
    static let cajas: [(String, Double, Double, Double, Double)] = [
        ("Lobos", 28.73, 28.77, -13.84, -13.79), ("La Graciosa", 29.21, 29.30, -13.55, -13.46),
        ("Alegranza y Montaña Clara", 29.36, 29.43, -13.54, -13.47),
        ("El Hierro", 27.62, 27.87, -18.17, -17.86), ("La Palma", 28.44, 28.87, -18.01, -17.71),
        ("La Gomera", 28.00, 28.23, -17.36, -17.08), ("Tenerife", 27.98, 28.60, -16.94, -16.10),
        ("Gran Canaria", 27.72, 28.19, -15.85, -15.34), ("Fuerteventura", 28.03, 28.77, -14.54, -13.81),
        ("Lanzarote", 28.83, 29.26, -13.89, -13.40),
    ]

    static func islaDe(lat: Double, lon: Double) -> String {
        if let c = cajas.first(where: { lat >= $0.1 && lat <= $0.2 && lon >= $0.3 && lon <= $0.4 }) { return c.0 }
        return lat > 27.4 && lat < 29.6 && lon > -18.4 && lon < -13.2 ? "Mar (Canarias)" : "Fuera de Canarias"
    }

    /// Código de isla (T, C…) para un nombre de isla, si es una de las siete
    static func codigoIsla(_ nombre: String) -> String? {
        Cat.islas.first { $0.1 == nombre }?.0
    }
}

/// Avistamiento en el formato de la copia de seguridad de la web (JSON), para exportar e importar
struct AvistamientoWeb: Codable {
    var id: String?
    var codigo: String
    var nombre: String?
    var comun: String?
    var fecha: String
    var individuos: Int?
    var estados: [String]?
    var notas: String?
    var lat: Double?
    var lon: Double?
    var precision: Double?
    var altitud: Double?
    var isla: String?
    var municipio: String?
    var paraje: String?
    var aproximado: Bool?
    var ajustadoAMano: Bool?
    var lugarPendiente: Bool?
    var tiempoPendiente: Bool?
    var tiempo: TiempoAv?

    enum CodingKeys: String, CodingKey {
        case id, codigo, nombre, comun, fecha, individuos, estados, notas, lat, lon, precision, altitud, isla, municipio, paraje
        case aproximado, ajustadoAMano, lugarPendiente, tiempoPendiente, tiempo
    }

    init(id: String?, codigo: String, fecha: String) {
        self.id = id; self.codigo = codigo; self.fecha = fecha
    }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ c: CodingKeys) -> Double? {
            if let d = try? k.decodeIfPresent(Double.self, forKey: c) { return d }
            if let s = try? k.decodeIfPresent(String.self, forKey: c) { return Double(s) }
            return nil
        }
        id = try? k.decodeIfPresent(String.self, forKey: .id)
        codigo = try k.decode(String.self, forKey: .codigo)
        nombre = try? k.decodeIfPresent(String.self, forKey: .nombre)
        comun = try? k.decodeIfPresent(String.self, forKey: .comun)
        fecha = try k.decode(String.self, forKey: .fecha)
        individuos = (try? k.decodeIfPresent(Int.self, forKey: .individuos)) ?? dbl(.individuos).map { Int($0) }
        estados = try? k.decodeIfPresent([String].self, forKey: .estados)
        notas = try? k.decodeIfPresent(String.self, forKey: .notas)
        lat = dbl(.lat); lon = dbl(.lon); precision = dbl(.precision); altitud = dbl(.altitud)
        isla = try? k.decodeIfPresent(String.self, forKey: .isla)
        municipio = try? k.decodeIfPresent(String.self, forKey: .municipio)
        paraje = try? k.decodeIfPresent(String.self, forKey: .paraje)
        aproximado = try? k.decodeIfPresent(Bool.self, forKey: .aproximado)
        ajustadoAMano = try? k.decodeIfPresent(Bool.self, forKey: .ajustadoAMano)
        lugarPendiente = try? k.decodeIfPresent(Bool.self, forKey: .lugarPendiente)
        tiempoPendiente = try? k.decodeIfPresent(Bool.self, forKey: .tiempoPendiente)
        tiempo = try? k.decodeIfPresent(TiempoAv.self, forKey: .tiempo)
    }

    /// Lee una copia de seguridad (lista JSON de avistamientos). Ignora las entradas sin código o sin fecha.
    static func leerCopia(_ datos: Data) throws -> [AvistamientoWeb] {
        guard let lista = try JSONSerialization.jsonObject(with: datos) as? [Any] else {
            throw NSError(domain: "Pokedex", code: 1, userInfo: [NSLocalizedDescriptionKey: "El archivo no es una lista de avistamientos"])
        }
        var out: [AvistamientoWeb] = []
        for x in lista {
            guard let o = x as? [String: Any], let c = o["codigo"] as? String, !c.isEmpty, let f = o["fecha"] as? String, !f.isEmpty,
                  let d = try? JSONSerialization.data(withJSONObject: o),
                  let a = try? JSONDecoder().decode(AvistamientoWeb.self, from: d) else { continue }
            out.append(a)
        }
        return out
    }

    static func copia(_ lista: [AvistamientoWeb]) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(lista)
    }

    static let columnasCSV = ["fecha", "codigo", "nombre", "comun", "individuos", "estados", "isla", "municipio", "paraje", "lat", "lon",
                              "precision", "altitud", "temperatura", "cielo", "viento", "direccion", "humedad", "lluvia", "nubosidad", "notas"]

    /// CSV con punto y coma (se abre bien en Excel en español)
    static func csv(_ lista: [AvistamientoWeb]) -> String {
        func num(_ d: Double?) -> String {
            guard let d else { return "" }
            if d == d.rounded() && abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        }
        let filas = lista.map { a -> String in
            let t = a.tiempo
            let v: [String: String] = [
                "fecha": a.fecha, "codigo": a.codigo, "nombre": a.nombre ?? "", "comun": a.comun ?? "",
                "individuos": a.individuos.map(String.init) ?? "", "estados": (a.estados ?? []).joined(separator: " | "),
                "isla": a.isla ?? "", "municipio": a.municipio ?? "", "paraje": a.paraje ?? "",
                "lat": num(a.lat), "lon": num(a.lon), "precision": num(a.precision), "altitud": num(a.altitud),
                "temperatura": num(t?.temperatura), "cielo": t?.codigo != nil ? Meteo.cielo(t?.codigo).0 : "",
                "viento": num(t?.viento), "direccion": Meteo.rumbo(t?.direccion), "humedad": num(t?.humedad),
                "lluvia": num(t?.lluvia), "nubosidad": num(t?.nubosidad), "notas": a.notas ?? "",
            ]
            return columnasCSV.map { c -> String in
                let x = v[c] ?? ""
                if x.contains(";") || x.contains("\"") || x.contains("\n") {
                    return "\"" + x.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return x
            }.joined(separator: ";")
        }
        return "\u{FEFF}" + ([columnasCSV.joined(separator: ";")] + filas).joined(separator: "\n")
    }
}
