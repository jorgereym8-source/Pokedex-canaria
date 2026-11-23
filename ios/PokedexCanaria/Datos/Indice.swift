import Foundation

/// Filtros de Explorar (mismos que la web)
struct Filtros: Equatable, Codable {
    var g: [String] = []      // grupo
    var i: [String] = []      // isla
    var nv: [String] = []     // endemicidad y origen
    var ui: [String] = []     // categoría UICN
    var cc: [String] = []     // Catálogo Canario
    var ce: [String] = []     // Catálogo Español
    var md: [String] = []     // medio
    var hb: [String] = []     // hábitat
    var inv = false           // solo invasoras
    var foto = false          // solo con foto
    var son = false           // solo con sonido
    var novistas = false      // ocultar las vistas
    var ext = false           // ocultar extinguidas
    var am = false            // solo amenazadas
    var pr = false            // solo protegidas (con ficha en Centinela)

    var cuantos: Int {
        [g, i, nv, ui, cc, ce, md, hb].reduce(0) { $0 + $1.count }
            + [inv, foto, son, novistas, ext, am, pr].filter { $0 }.count
    }

    var vacio: Bool { cuantos == 0 }

    /// Si solo hay una isla elegida, la lista usa la numeración regional de esa isla
    var islaUnica: String? { i.count == 1 ? i[0] : nil }
}

enum Orden: String, CaseIterable, Identifiable {
    case no, az, sci
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .no: return "Nº Pokédex"
        case .az: return "Nombre común"
        case .sci: return "Nombre científico"
        }
    }
    /// Orden por defecto según el ajuste «Orden por defecto»
    static func desde(ajuste: String) -> Orden {
        switch ajuste {
        case "Nombre común": return .az
        case "Nombre científico": return .sci
        default: return .no
        }
    }
}

enum Indice {
    /// Calcula los campos derivados: texto de búsqueda, islas, género y Pokédex regional
    static func preparar(_ lista: [Especie]) {
        for e in lista {
            e.busqueda = normalizar([e.nombre, e.comunes.joined(separator: " "), e.familia, e.codigo, e.clase].joined(separator: " "))
            e.islas = islasDe(e.presenciaIslas)
            e.genero = String(e.nombre.split(separator: " ").first ?? "")
            e.claveComun = normalizar(e.nombreComun)
            e.claveCientifico = e.nombre.lowercased()
            e.regional = [:]
        }
        // Pokédex regional: numeración propia de cada isla, en el mismo orden que la general
        let ordenada = lista.sorted { $0.numero < $1.numero }
        for (k, _) in Cat.islas {
            var n = 0
            for e in ordenada where e.islas.contains(k) {
                n += 1
                e.regional[k] = n
            }
        }
    }

    static func cumple(_ e: Especie, palabras: [String], f: Filtros, vistas: Set<String>) -> Bool {
        if !palabras.isEmpty && !palabras.allSatisfy({ e.busqueda.contains($0) }) { return false }
        if !f.g.isEmpty && !f.g.contains(e.grupo) { return false }
        if !f.i.isEmpty && !f.i.contains(where: { e.islas.contains($0) }) { return false }
        if !f.nv.isEmpty && !f.nv.contains(e.nivel) { return false }
        if !f.ui.isEmpty && !f.ui.contains(e.uicn) { return false }
        if f.inv && e.origen != "ISI" { return false }
        if !f.cc.isEmpty && !f.cc.contains(where: { e.catCanario.contains($0) }) { return false }
        if !f.ce.isEmpty && !f.ce.contains(where: { e.catEspanol.contains($0) }) { return false }
        if !f.md.isEmpty && !f.md.contains(e.medio) { return false }
        if !f.hb.isEmpty && !f.hb.contains(where: { e.habitats.contains($0) }) { return false }
        if f.foto && e.imagen == nil && e.fotoLibre == nil { return false }
        if f.son && !e.conSonido { return false }
        if f.novistas && vistas.contains(e.codigo) { return false }
        if f.ext && e.esExtinta { return false }
        if f.am && !e.esAmenazada { return false }
        if f.pr && !e.protegida { return false }
        return true
    }

    static func palabras(_ q: String) -> [String] {
        normalizar(q).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func filtrar(_ lista: [Especie], q: String, f: Filtros, vistas: Set<String>, orden: Orden) -> [Especie] {
        let p = palabras(q)
        var r = lista.filter { cumple($0, palabras: p, f: f, vistas: vistas) }
        switch orden {
        case .az: r.sort { $0.claveComun == $1.claveComun ? $0.numero < $1.numero : $0.claveComun < $1.claveComun }
        case .sci: r.sort { $0.claveCientifico == $1.claveCientifico ? $0.numero < $1.numero : $0.claveCientifico < $1.claveCientifico }
        case .no: r.sort { $0.numero < $1.numero }
        }
        return r
    }

    static func contar(_ lista: [Especie], q: String, f: Filtros, vistas: Set<String>) -> Int {
        let p = palabras(q)
        return lista.reduce(0) { $0 + (cumple($1, palabras: p, f: f, vistas: vistas) ? 1 : 0) }
    }

    static func cuentaPorGrupo(_ lista: [Especie]) -> [String: Int] {
        var c: [String: Int] = [:]
        for e in lista { c[e.grupo, default: 0] += 1 }
        return c
    }

    /// Especie del día: la misma durante todo el día (y la misma que en la web), entre las que tienen foto
    static func especieDelDia(_ lista: [Especie], fecha: Date = Date()) -> Especie? {
        let con = lista.filter { $0.imagen != nil && $0.nivel != "introducido" && !$0.esExtinta }
        let l = con.isEmpty ? lista : con
        guard !l.isEmpty else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let ano = cal.component(.year, from: fecha)
        let dia = cal.ordinality(of: .day, in: .year, for: fecha) ?? 1
        let semilla = ano * 1000 + dia
        let i = (semilla * 2654435761) % l.count
        return l[i]
    }

    /// Mismo género en Canarias, sin la propia especie
    static func mismoGenero(_ e: Especie, en lista: [Especie]) -> [Especie] {
        lista.filter { $0.genero == e.genero && $0.codigo != e.codigo }.sorted { $0.numero < $1.numero }
    }

    /// Progreso por isla: total de especies y cuántas has visto
    static func progresoIslas(_ lista: [Especie], vistas: Set<String>) -> [String: (total: Int, vistas: Int)] {
        var out: [String: (total: Int, vistas: Int)] = [:]
        for (k, _) in Cat.islas { out[k] = (0, 0) }
        for e in lista {
            let vista = vistas.contains(e.codigo)
            for k in e.islas {
                guard var p = out[k] else { continue }
                p.total += 1
                if vista { p.vistas += 1 }
                out[k] = p
            }
        }
        return out
    }

    static func habitatsFrecuentes(_ lista: [Especie], n: Int = 14) -> [String] {
        var c: [String: Int] = [:]
        for e in lista { for h in e.habitats { c[h, default: 0] += 1 } }
        return c.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(n).map { $0.key }
    }
}
