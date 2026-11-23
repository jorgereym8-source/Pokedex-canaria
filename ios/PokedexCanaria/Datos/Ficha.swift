import Foundation

/// Ficha completa de una especie (datos/fichas/CODIGO.json). Todo es opcional:
/// si a una ficha le falta un bloque, la sección correspondiente simplemente no se muestra.
struct Ficha {
    struct ImagenBiota: Hashable { let id: String; let credito: String }
    struct Origen { let nombre: String; let codigo: String; let definicion: String }
    struct Proteccion { let catalogo: String; let islas: [(isla: String, categoria: String, definicion: String)] }
    struct Enlace: Hashable { let titulo: String; let url: String }
    struct UICN { let categoria: String; let codigo: String; let url: String?; let nivel: String? }
    struct Tamano { let tipo: String; let min: Double?; let max: Double; let fuente: String; let url: String?; let cita: String?; let nivel: String? }
    struct Peso { let kg: Double; let tipo: String; let fuente: String; let url: String? }
    struct Longevidad { let anos: Double; let tipo: String; let origen: String; let fuente: String; let url: String? }
    struct Dato { let valor: String; let fuente: String }
    struct FotoLibre: Hashable { let archivo: String?; let url: String?; let autor: String; let fuente: String; let lic: String; let licUrl: String?; let nivel: String; let pagina: String?; let taxon: String? }
    struct EVC { let url: String; let autoria: String; let titulo: String }
    struct Rasgo: Hashable { let grupo: String; let k: String; let v: String; let fuente: String; let url: String? }
    struct Sonido: Hashable { let url: String; let autor: String; let canarias: Bool; let fuente: String; let lic: String; let licUrl: String?; let lugar: String; let pagina: String?; let tipo: String }
    struct Altitud { let p5: Int; let p95: Int; let min: Int; let max: Int; let n: Int; let url: String? }
    struct Mundo { let nativa: [String]; let introducida: [String]; let url: String?; let nivel: String?; let nombre: String? }
    struct Art17 { let ambito: String; let estado: String; let tendencia: String?; let periodo: String; let url: String?; let parametros: [(String, String)] }
    struct Art12 { let ambito: String; let estacion: String?; let poblacion: String?; let fechaPoblacion: String?; let tendencia: String?; let tendenciaLarga: String?; let periodo: String; let url: String? }
    struct EspacioNatura: Hashable { let codigo: String; let nombre: String; let tipo: String }
    struct Introduccion { let origen: String?; let fecha: String?; let via: String?; let dispersion: String?; let islas: String?; let autor: String?; let ano: String?; let nombre: String?; let url: String?; let pagina: Int? }
    struct PrimerRegistro { let ano: Int; let tipo: String?; let url: String? }
    struct TallaMinima { let valor: String; let especieNorma: String; let url: String? }
    struct Etimologia { let texto: String; let fuente: String; let url: String? }
    struct Vulnerabilidad { let categoria: String?; let indice: String?; let fuente: String; let url: String? }

    var codigo = ""
    var nombre = ""
    var autor = ""
    var comunes: [String] = []
    var reino = ""
    var grupo = ""
    var medio = ""
    var clase = ""
    var validez = ""
    var status = ""
    var actualizado = ""
    var fichaPendiente = false
    var imagenes: [ImagenBiota] = []
    var mapaPk: String?
    var origen: Origen?
    var habitats: [String] = []
    var taxonomia: [(rango: String, valor: String)] = []
    var sinonimos = 0
    var referencias = 0
    var proteccion: [Proteccion] = []
    var enlaces: [Enlace] = []
    var centinela: (pdf: Bool, secciones: [(titulo: String, texto: String)])?
    var uicn: UICN?
    var tamano: Tamano?
    var peso: Peso?
    var longevidad: Longevidad?
    var ciclo: Dato?
    var forma: Dato?
    var fotosLibres: [FotoLibre] = []
    var evc: EVC?
    var rasgos: [Rasgo] = []
    var sonidos: [Sonido] = []
    var altitud: Altitud?
    var mundo: Mundo?
    var gbifClave: Int?
    var art17: Art17?
    var art12: Art12?
    var natura2000: [EspacioNatura] = []
    var introduccion: Introduccion?
    var primerRegistro: PrimerRegistro?
    var tallaMinima: TallaMinima?
    var etimologia: Etimologia?
    var vulnerabilidad: Vulnerabilidad?

    /// Sección de Centinela por título
    func seccion(_ t: String) -> String? { centinela?.secciones.first { $0.titulo == t }?.texto }

    init() {}

    init(json j: JSON) {
        codigo = j["codigo"]?.texto ?? ""
        nombre = j["nombre"]?.texto ?? ""
        autor = j["autor"]?.texto ?? ""
        comunes = j["comunes"]?.textos ?? []
        reino = j["reino"]?.texto ?? ""
        grupo = j["grupo"]?.texto ?? ""
        medio = j["medio"]?.texto ?? ""
        clase = j["clase"]?.texto ?? ""
        validez = j["validez"]?.texto ?? ""
        status = j["status"]?.texto ?? ""
        actualizado = j["actualizado"]?.texto ?? ""
        fichaPendiente = j["fichaPendiente"]?.logico ?? false
        imagenes = (j["imagenes"]?.lista ?? []).compactMap { im in
            guard let id = im["id"]?.textoNoVacio else { return nil }
            return ImagenBiota(id: id, credito: im["credito"]?.textoNoVacio ?? im["autor"]?.textoNoVacio ?? "Biota")
        }
        mapaPk = j["mapaPk"]?.textoNoVacio
        if let o = j["origen"], o.esObjeto {
            origen = Origen(nombre: o["nombre"]?.texto ?? "", codigo: o["codigo"]?.texto ?? "", definicion: o["definicion"]?.texto ?? "")
        }
        var hs: [String] = []
        for h in j["habitats"]?.lista ?? [] {
            if let c = h["categoria"]?.textoNoVacio, !hs.contains(c) { hs.append(c) }
        }
        habitats = hs
        taxonomia = (j["taxonomia"]?.pares ?? []).compactMap { k, v in v.texto.map { (rango: k, valor: $0) } }
        sinonimos = j["sinonimos"]?.entero ?? 0
        referencias = j["referencias"]?.entero ?? 0
        proteccion = (j["proteccion"]?.pares ?? []).map { cat, islas in
            Proteccion(catalogo: cat, islas: islas.pares.map { isla, d in
                (isla: isla, categoria: d["categoria"]?.texto ?? "", definicion: d["definicion"]?.texto ?? "")
            })
        }
        enlaces = (j["enlaces"]?.lista ?? []).compactMap { e in
            guard let u = e["url"]?.textoNoVacio else { return nil }
            return Enlace(titulo: e["titulo"]?.texto ?? "", url: u)
        }
        if let c = j["centinela"], c.esObjeto {
            let secs = (c["secciones"]?.pares ?? []).compactMap { k, v in v.textoNoVacio.map { (titulo: k, texto: $0) } }
            centinela = (pdf: c["pdf"]?.logico ?? false, secciones: secs)
        }
        if let u = j["uicn"], u.esObjeto, let cod = u["codigo"]?.textoNoVacio {
            uicn = UICN(categoria: u["categoria"]?.texto ?? cod, codigo: cod, url: u["url"]?.textoNoVacio, nivel: u["nivel"]?.textoNoVacio)
        }
        if let t = j["tamano"], t.esObjeto, let max = t["max"]?.numero, max > 0 {
            tamano = Tamano(tipo: t["tipo"]?.texto ?? "tamaño", min: t["min"]?.numero, max: max, fuente: t["fuente"]?.texto ?? "",
                            url: t["url"]?.textoNoVacio, cita: t["cita"]?.textoNoVacio, nivel: t["nivel"]?.textoNoVacio)
        }
        if let p = j["peso"], p.esObjeto, let kg = p["kg"]?.numero {
            peso = Peso(kg: kg, tipo: p["tipo"]?.texto ?? "", fuente: p["fuente"]?.texto ?? "", url: p["url"]?.textoNoVacio)
        }
        if let l = j["longevidad"], l.esObjeto, let a = l["anos"]?.numero {
            longevidad = Longevidad(anos: a, tipo: l["tipo"]?.texto ?? "", origen: l["origen"]?.texto ?? "", fuente: l["fuente"]?.texto ?? "", url: l["url"]?.textoNoVacio)
        }
        if let c = j["ciclo"], let v = c["valor"]?.textoNoVacio { ciclo = Dato(valor: v, fuente: c["fuente"]?.texto ?? "") }
        if let f = j["forma"], let v = f["valor"]?.textoNoVacio { forma = Dato(valor: v, fuente: f["fuente"]?.texto ?? "") }
        fotosLibres = (j["fotosLibres"]?.lista ?? []).compactMap { x in
            let archivo = x["archivo"]?.textoNoVacio, url = x["url"]?.textoNoVacio
            guard archivo != nil || url != nil else { return nil }
            return FotoLibre(archivo: archivo, url: url, autor: x["autor"]?.texto ?? "", fuente: x["fuente"]?.texto ?? "",
                             lic: x["lic"]?.texto ?? "", licUrl: x["licUrl"]?.textoNoVacio, nivel: x["nivel"]?.texto ?? "",
                             pagina: x["pagina"]?.textoNoVacio, taxon: x["taxon"]?.textoNoVacio)
        }
        if let e = j["evc"], let u = e["url"]?.textoNoVacio {
            evc = EVC(url: u, autoria: e["autoria"]?.texto ?? "", titulo: e["titulo"]?.texto ?? "")
        }
        rasgos = (j["rasgos"]?.lista ?? []).compactMap { r in
            guard let k = r["k"]?.textoNoVacio, let v = r["v"]?.textoNoVacio else { return nil }
            return Rasgo(grupo: r["grupo"]?.texto ?? "Otros", k: k, v: v, fuente: r["fuente"]?.texto ?? "", url: r["url"]?.textoNoVacio)
        }
        sonidos = (j["sonidos"]?.lista ?? []).compactMap { s in
            guard let u = s["url"]?.textoNoVacio else { return nil }
            return Sonido(url: u, autor: s["autor"]?.texto ?? "", canarias: s["canarias"]?.logico ?? false, fuente: s["fuente"]?.texto ?? "",
                          lic: s["lic"]?.texto ?? "", licUrl: s["licUrl"]?.textoNoVacio, lugar: s["lugar"]?.texto ?? "",
                          pagina: s["pagina"]?.textoNoVacio, tipo: s["tipo"]?.texto ?? "")
        }
        if let a = j["altitud"], a.esObjeto, let p5 = a["p5"]?.entero, let p95 = a["p95"]?.entero {
            altitud = Altitud(p5: p5, p95: p95, min: a["min"]?.entero ?? p5, max: a["max"]?.entero ?? p95, n: a["n"]?.entero ?? 0, url: a["url"]?.textoNoVacio)
        }
        if let m = j["mundo"], m.esObjeto {
            mundo = Mundo(nativa: m["nativa"]?.textos ?? [], introducida: m["introducida"]?.textos ?? [], url: m["url"]?.textoNoVacio,
                          nivel: m["nivel"]?.textoNoVacio, nombre: m["nombre"]?.textoNoVacio)
        }
        gbifClave = j["gbifClave"]?.entero
        if let a = j["art17"], a.esObjeto, let estado = a["estado"]?.textoNoVacio {
            let ps = (a["parametros"]?.pares ?? []).compactMap { k, v in v.textoNoVacio.map { (k, $0) } }
            art17 = Art17(ambito: a["ambito"]?.texto ?? "", estado: estado, tendencia: a["tendencia"]?.textoNoVacio,
                          periodo: a["periodo"]?.texto ?? "", url: a["url"]?.textoNoVacio, parametros: ps)
        }
        if let a = j["art12"], a.esObjeto {
            let x = Art12(ambito: a["ambito"]?.texto ?? "", estacion: a["estacion"]?.textoNoVacio, poblacion: a["poblacion"]?.textoNoVacio,
                          fechaPoblacion: a["fechaPoblacion"]?.textoNoVacio, tendencia: a["tendencia"]?.textoNoVacio,
                          tendenciaLarga: a["tendenciaLarga"]?.textoNoVacio, periodo: a["periodo"]?.texto ?? "", url: a["url"]?.textoNoVacio)
            if x.poblacion != nil || x.tendencia != nil { art12 = x }
        }
        natura2000 = (j["natura2000"]?["espacios"]?.lista ?? []).compactMap { e in
            guard let c = e["codigo"]?.textoNoVacio else { return nil }
            return EspacioNatura(codigo: c, nombre: e["nombre"]?.texto ?? c, tipo: e["tipo"]?.texto ?? "")
        }
        if let d = j["introduccion"], d.esObjeto {
            introduccion = Introduccion(origen: d["origen"]?.textoNoVacio, fecha: d["fecha"]?.textoNoVacio, via: d["via"]?.textoNoVacio,
                                        dispersion: d["dispersion"]?.textoNoVacio, islas: d["islas"]?.textoNoVacio, autor: d["autor"]?.textoNoVacio,
                                        ano: d["ano"]?.textoNoVacio, nombre: d["nombre"]?.textoNoVacio, url: d["url"]?.textoNoVacio, pagina: d["pagina"]?.entero)
        }
        if let p = j["primerRegistro"], let a = p["ano"]?.entero {
            primerRegistro = PrimerRegistro(ano: a, tipo: p["tipo"]?.textoNoVacio, url: p["url"]?.textoNoVacio)
        }
        if let t = j["tallaMinima"], let v = t["valor"]?.textoNoVacio {
            tallaMinima = TallaMinima(valor: v, especieNorma: t["especieNorma"]?.texto ?? "", url: t["url"]?.textoNoVacio)
        }
        if let e = j["etimologia"], let t = e["texto"]?.textoNoVacio {
            etimologia = Etimologia(texto: t.replacingOccurrences(of: "\u{200B}", with: ""), fuente: e["fuente"]?.texto ?? "", url: e["url"]?.textoNoVacio)
        }
        if let v = j["vulnerabilidad"], v.esObjeto {
            vulnerabilidad = Vulnerabilidad(categoria: v["categoria"]?.textoNoVacio, indice: v["indice"]?.textoNoVacio,
                                            fuente: v["fuente"]?.texto ?? "", url: v["url"]?.textoNoVacio)
        }
    }
}

// MARK: - Fotos

struct Foto: Hashable, Identifiable {
    let url: URL
    let pie: String
    let enlace: URL?
    var id: URL { url }
}

enum URLsFotos {
    /// Foto de Biota (enlazada desde su web)
    static func biota(_ codigo: String, _ id: String, mini: Bool = false) -> URL? {
        URL(string: "\(Cat.biota)/especie/\(codigo)/imagenes/\(id)\(mini ? "?thumbnails=true" : "")")
    }

    /// Foto con licencia libre: «c:Archivo.jpg» (Commons) o «i:123/medium.jpg» (iNaturalist) o una URL completa
    static func libre(_ fl: String, ancho: Int = 960) -> URL? {
        if fl.hasPrefix("c:") {
            let archivo = String(fl.dropFirst(2))
            // Igual que encodeURIComponent
            let permitidos = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
            let cod = archivo.addingPercentEncoding(withAllowedCharacters: permitidos) ?? archivo
            return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(cod)?width=\(ancho)")
        }
        var u = fl.hasPrefix("i:") ? "https://inaturalist-open-data.s3.amazonaws.com/photos/\(fl.dropFirst(2))" : fl
        let tam = ancho <= 250 ? "/small." : "/medium."
        for t in ["/medium.", "/small."] where u.contains(t) {
            u = u.replacingOccurrences(of: t, with: tam)
            break
        }
        return URL(string: u)
    }

    /// Foto principal de una entrada del índice según los ajustes
    static func principal(_ e: Especie, biota: Bool, libres: Bool, ancho: Int = 960) -> (url: URL, credito: String)? {
        if biota, let img = e.imagen, let u = URLsFotos.biota(e.codigo, img, mini: ancho <= 250) { return (u, "Foto: Biota") }
        if libres, let fl = e.fotoLibre, let u = URLsFotos.libre(fl, ancho: ancho) {
            return (u, fl.hasPrefix("c:") ? "Foto: Wikimedia Commons" : "Foto: iNaturalist")
        }
        return nil
    }

    /// Fotos de la ficha (hasta 10)
    static func deFicha(_ f: Ficha, codigo: String, biota: Bool, libres: Bool) -> [Foto] {
        var out: [Foto] = []
        if biota {
            for im in f.imagenes {
                if let u = URLsFotos.biota(codigo, im.id) { out.append(Foto(url: u, pie: "Foto: \(im.credito) · Biota", enlace: nil)) }
            }
        }
        if libres {
            for x in f.fotosLibres {
                let esCommons = x.fuente == "Wikimedia Commons"
                guard let u = esCommons ? x.archivo.flatMap({ URLsFotos.libre("c:" + $0) }) : x.url.flatMap({ URLsFotos.libre($0) }) else { continue }
                var pie = ""
                if x.nivel == "especie", let t = x.taxon { pie += "Foto de \(t) · " }
                if x.nivel == "sinonimo", let t = x.taxon { pie += "Como \(t) en iNaturalist · " }
                pie += "\(x.autor) · \(x.lic) · \(esCommons ? "Commons" : "iNaturalist")"
                out.append(Foto(url: u, pie: pie, enlace: x.pagina.flatMap { URL(string: $0) }))
            }
        }
        var vistos = Set<URL>()
        return Array(out.filter { vistos.insert($0.url).inserted }.prefix(10))
    }

    static func fuentes(_ f: Ficha) -> String {
        var l: [String] = []
        if !f.imagenes.isEmpty { l.append("Biota (desde su web)") }
        for x in f.fotosLibres where !l.contains(x.fuente) { l.append(x.fuente) }
        if f.evc != nil { l.append("enlace a Especies Vegetales en Canarias") }
        return l.joined(separator: " · ")
    }
}

// MARK: - Medidas

enum Medidas {
    static func medida(_ m: Double) -> String {
        if m >= 1 { return "\(decimal(m, 1)) m" }
        if m >= 0.01 { return "\(Int((m * 100).rounded())) cm" }
        return "\(Int((m * 1000).rounded())) mm"
    }

    static func textoTamano(min: Double?, max: Double) -> String {
        var rango = "hasta \(medida(max))"
        if let mn = min, mn > 0 {
            let a = medida(mn), b = medida(max)
            let pa = a.split(separator: " "), pb = b.split(separator: " ")
            if pa.count == 2, pb.count == 2, pa[1] == pb[1] { rango = "\(pa[0])–\(b)" } else { rango = "\(a)–\(b)" }
        }
        return conMayuscula(rango)
    }

    static func textoTamano(_ t: Ficha.Tamano) -> String { textoTamano(min: t.min, max: t.max) }

    static func peso(_ kg: Double) -> String {
        if kg >= 1000 { return "\(decimal(kg / 1000, 1)) t" }
        if kg >= 1 { return "\(decimal(kg, 1)) kg" }
        return "\(decimal(kg * 1000, 1)) g"
    }

    static func anos(_ a: Double) -> String { "\(decimal(a, 1)) años" }
}
