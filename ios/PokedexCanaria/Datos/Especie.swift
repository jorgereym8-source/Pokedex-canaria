import Foundation

/// Una entrada del índice de especies (datos/indice.json): lo justo para listas, búsquedas y filtros.
final class Especie: Identifiable, Hashable, Decodable {
    let codigo: String          // c: código de Biota
    let nombre: String          // n: nombre científico
    let autor: String           // a: autoría
    let rango: String           // r
    let comunes: [String]       // cm
    let reino: String           // re: Flora | Fauna
    let grupo: String           // g
    let subgrupo: String?       // sg
    let clase: String           // cl
    let familia: String         // fa
    let medio: String           // md: Terrestre | Marino
    let presenciaIslas: String  // is: "HsPsTd…"
    let origen: String          // o: NS, ISI…
    let nivel: String           // nv: insular, canario…
    let status: String          // st: Actual | Extinto
    let habitats: [String]      // hb
    let catCanario: [String]    // cc
    let catEspanol: [String]    // ce
    let protegida: Bool         // pr: con ficha en Centinela
    let imagen: String?         // img: id de la foto de portada de Biota
    let nImagenes: Int          // ni
    let uicn: String            // ui
    let forma: String           // fm
    let tamano: Double?         // tm (m)
    let numero: Int             // no: número de Pokédex (orden taxonómico)
    let fotoLibre: String?      // fl: «c:Archivo.jpg» (Commons) o «i:123/medium.jpg» (iNaturalist)
    let enEVC: Bool             // ev: tiene ficha en Especies Vegetales en Canarias
    let enNatura: Bool          // n2
    let conSonido: Bool         // so

    // Derivados (se calculan al cargar el índice)
    var busqueda = ""
    var islas: [String] = []
    var genero = ""
    var regional: [String: Int] = [:]
    var claveComun = ""
    var claveCientifico = ""

    var id: String { codigo }

    /// Nombre común principal o, si no hay, el científico
    var nombreComun: String { comunes.first ?? nombre }

    var esFlora: Bool { reino == "Flora" }

    var esAmenazada: Bool {
        if ["CR", "EN", "VU"].contains(uicn) { return true }
        return (catCanario + catEspanol).contains { Especie.esCategoriaAmenaza($0) }
    }

    static func esCategoriaAmenaza(_ c: String) -> Bool {
        let n = c.lowercased()
        return n.contains("peligro") || n.contains("vulnerable")
    }

    var esExtinta: Bool { status == "Extinto" }

    enum Claves: String, CodingKey {
        case c, n, a, r, cm, re, g, sg, cl, fa, md, o, nv, st, hb, cc, ce, pr, img, ni, ui, fm, tm, no, fl, ev, n2, so
        case presenciaIslas = "is"
    }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: Claves.self)
        codigo = try k.decode(String.self, forKey: .c)
        nombre = (try? k.decodeIfPresent(String.self, forKey: .n)) ?? codigo
        autor = (try? k.decodeIfPresent(String.self, forKey: .a)) ?? ""
        rango = (try? k.decodeIfPresent(String.self, forKey: .r)) ?? ""
        comunes = (try? k.decodeIfPresent([String].self, forKey: .cm)) ?? []
        reino = (try? k.decodeIfPresent(String.self, forKey: .re)) ?? ""
        grupo = (try? k.decodeIfPresent(String.self, forKey: .g)) ?? ""
        subgrupo = try? k.decodeIfPresent(String.self, forKey: .sg)
        clase = (try? k.decodeIfPresent(String.self, forKey: .cl)) ?? ""
        familia = (try? k.decodeIfPresent(String.self, forKey: .fa)) ?? ""
        medio = (try? k.decodeIfPresent(String.self, forKey: .md)) ?? ""
        presenciaIslas = (try? k.decodeIfPresent(String.self, forKey: .presenciaIslas)) ?? ""
        origen = (try? k.decodeIfPresent(String.self, forKey: .o)) ?? ""
        nivel = (try? k.decodeIfPresent(String.self, forKey: .nv)) ?? ""
        status = (try? k.decodeIfPresent(String.self, forKey: .st)) ?? ""
        habitats = (try? k.decodeIfPresent([String].self, forKey: .hb)) ?? []
        catCanario = (try? k.decodeIfPresent([String].self, forKey: .cc)) ?? []
        catEspanol = (try? k.decodeIfPresent([String].self, forKey: .ce)) ?? []
        protegida = (try? k.decodeIfPresent(Bool.self, forKey: .pr)) ?? false
        imagen = try? k.decodeIfPresent(String.self, forKey: .img)
        nImagenes = (try? k.decodeIfPresent(Int.self, forKey: .ni)) ?? 0
        uicn = (try? k.decodeIfPresent(String.self, forKey: .ui)) ?? "NE"
        forma = (try? k.decodeIfPresent(String.self, forKey: .fm)) ?? ""
        tamano = try? k.decodeIfPresent(Double.self, forKey: .tm)
        numero = (try? k.decodeIfPresent(Int.self, forKey: .no)) ?? 0
        fotoLibre = try? k.decodeIfPresent(String.self, forKey: .fl)
        enEVC = ((try? k.decodeIfPresent(Int.self, forKey: .ev)) ?? 0) != 0
        enNatura = ((try? k.decodeIfPresent(Int.self, forKey: .n2)) ?? 0) != 0
        conSonido = ((try? k.decodeIfPresent(Int.self, forKey: .so)) ?? 0) != 0
    }

    static func == (a: Especie, b: Especie) -> Bool { a.codigo == b.codigo }
    func hash(into h: inout Hasher) { h.combine(codigo) }
}

/// Resumen de datos/meta.json
struct MetaDatos: Decodable {
    let actualizado: String
    let taxones: Int?

    /// Fecha de la actualización
    var fecha: Date? { Fechas.iso(actualizado) }
}

enum Fechas {
    static func iso(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: s) { return d }
        let f3 = DateFormatter()
        f3.locale = Locale(identifier: "en_US_POSIX")
        f3.timeZone = TimeZone(identifier: "UTC")
        for formato in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f3.dateFormat = formato
            if let d = f3.date(from: s) { return d }
        }
        return nil
    }

    static func isoTexto(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    static let es = Locale(identifier: "es_ES")

    /// 23/11/2026
    static func corta(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "d/M/yyyy"
        return f.string(from: d)
    }

    /// 23 nov · 16:05
    static func diaHora(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "d MMM"
        let h = DateFormatter()
        h.locale = es
        h.dateFormat = "HH:mm"
        return "\(f.string(from: d).replacingOccurrences(of: ".", with: "")) · \(h.string(from: d))"
    }

    /// lunes, 23 de noviembre de 2026, 16:05
    static func larga(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = es
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: d)
    }

    /// «noviembre 2026»
    static func mesAno(_ d: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: d)
        return "\(Cat.mesesLargos[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }
}
