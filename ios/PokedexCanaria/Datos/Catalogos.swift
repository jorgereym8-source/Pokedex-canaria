import Foundation

/// Tablas fijas que comparte toda la app (las mismas que js/ui.js y js/app.js de la versión web).
enum Cat {
    static let biota = "https://www.biodiversidadcanarias.es/biota"
    static let centinela = "https://www.biodiversidadcanarias.es/centinela"
    static let redexos = "https://www.gobiernodecanarias.org/medioambiente/materias/biodiversidad/especies-exoticas-invasoras/"
    /// Web de la app (GitHub Pages): de aquí salen las actualizaciones de datos y los enlaces para compartir.
    static let web = "https://jorgereym8-source.github.io/Pokedex-canaria/"
    /// Copia directa del repositorio en GitHub, por si GitHub Pages no responde
    static let repositorio = "https://raw.githubusercontent.com/jorgereym8-source/Pokedex-canaria/main/"

    /// Islas de oeste a este
    static let islas: [(String, String)] = [
        ("H", "El Hierro"), ("P", "La Palma"), ("G", "La Gomera"), ("T", "Tenerife"),
        ("C", "Gran Canaria"), ("F", "Fuerteventura"), ("L", "Lanzarote"),
    ]
    /// Orden de las islas en Inicio y en el mapa
    static let islasOrden = ["T", "C", "P", "G", "H", "F", "L"]
    static let nombreIsla: [String: String] = Dictionary(uniqueKeysWithValues: islas.map { ($0.0, $0.1) })
    static let sigla: [String: String] = ["H": "EH", "P": "LP", "G": "LG", "T": "TF", "C": "GC", "F": "FV", "L": "LZ"]

    static let niveles: [(String, String)] = [
        ("insular", "Exclusivo de una isla"), ("canario", "Endemismo canario"), ("macaronesico", "Endemismo macaronésico"),
        ("nativo", "Nativo no endémico"), ("introducido", "Introducido"),
    ]
    static let nombreNivel: [String: String] = Dictionary(uniqueKeysWithValues: niveles.map { ($0.0, $0.1) })

    static let origenes: [String: String] = [
        "NS": "Nativo seguro", "NP": "Nativo probable", "IP": "Introducido probable", "ISI": "Introducido invasor",
        "ISN": "Introducido no invasor", "ISP": "Introducido potencialmente invasor", "ISF": "Introducido con falta de datos",
    ]

    struct CategoriaUICN { let codigo: String; let nombre: String; let color: String; let texto: String }
    static let uicn: [CategoriaUICN] = [
        .init(codigo: "CR", nombre: "En peligro crítico", color: "#D81E05", texto: "#FFFFFF"),
        .init(codigo: "EN", nombre: "En peligro", color: "#FC7F3F", texto: "#1C211B"),
        .init(codigo: "VU", nombre: "Vulnerable", color: "#F9E814", texto: "#1C211B"),
        .init(codigo: "NT", nombre: "Casi amenazada", color: "#CCE226", texto: "#1C211B"),
        .init(codigo: "LC", nombre: "Preocupación menor", color: "#60C659", texto: "#1C211B"),
        .init(codigo: "DD", nombre: "Datos insuficientes", color: "#D1D1C6", texto: "#1C211B"),
        .init(codigo: "NE", nombre: "No evaluada", color: "#D1D1C6", texto: "#1C211B"),
        .init(codigo: "EX", nombre: "Extinta", color: "#000000", texto: "#FFFFFF"),
        .init(codigo: "EW", nombre: "Extinta en estado silvestre", color: "#542344", texto: "#FFFFFF"),
    ]
    static func categoriaUICN(_ c: String) -> CategoriaUICN? { uicn.first { $0.codigo == c } }

    static let iconoGrupo: [String: String] = [
        "Helechos": "helecho", "Plantas con flor": "hoja", "Aves": "ave", "Reptiles": "lagarto", "Mamíferos": "pata",
        "Anfibios": "rana", "Peces": "pez", "Insectos": "insecto", "Arácnidos": "arana", "Moluscos": "caracol",
        "Crustáceos": "cangrejo", "Miriápodos": "ciempies", "Anélidos": "gusano", "Cnidarios": "medusa",
        "Equinodermos": "estrella", "Esponjas": "esponja", "Otros invertebrados": "gusano",
    ]
    static func icono(grupo: String) -> String { iconoGrupo[grupo] ?? "hoja" }

    static let grupos = ["Plantas con flor", "Helechos", "Aves", "Reptiles", "Mamíferos", "Anfibios", "Peces", "Insectos", "Arácnidos",
                         "Moluscos", "Crustáceos", "Miriápodos", "Anélidos", "Cnidarios", "Equinodermos", "Esponjas", "Otros invertebrados"]

    static let bloques: [(String, [String])] = [
        ("Flora", ["Plantas con flor", "Helechos"]),
        ("Vertebrados", ["Aves", "Reptiles", "Mamíferos", "Anfibios", "Peces"]),
        ("Invertebrados", ["Insectos", "Arácnidos", "Moluscos", "Crustáceos", "Miriápodos", "Anélidos", "Cnidarios", "Equinodermos", "Esponjas", "Otros invertebrados"]),
    ]

    static let catalogoCanario = ["En peligro de extinción", "Vulnerable", "Interés para los ecosistemas canarios", "Protección especial"]
    static let catalogoEspanol = ["En peligro de extinción", "Vulnerable", "Régimen de protección especial"]

    /// Siglas de las categorías de protección
    static let corto: [String: String] = [
        "En peligro de extinción": "EN", "Vulnerable": "VU", "Protección especial": "PE", "Régimen de protección especial": "PE",
        "Interés para los ecosistemas canarios": "IEC", "Sensible a la alteración de su hábitat": "SAH", "De interés especial": "IE",
    ]
    static func sigla(categoria c: String) -> String {
        if let s = corto[c] { return s }
        for p in ["Anexo ", "Anejo ", "Anexo", "Anejo"] where c.hasPrefix(p) {
            let r = String(c.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            return r.isEmpty ? c : r
        }
        return c
    }

    static let tipoSitio: [String: String] = ["A": "ZEPA", "B": "ZEC", "C": "ZEC y ZEPA"]
    static let siglaEstado: [String: String] = ["favorable": "FV", "desfavorable-inadecuado": "U1", "desfavorable-malo": "U2", "desconocido": "XX"]
    static let uicnDeEstado: [String: String] = ["favorable": "LC", "desfavorable-inadecuado": "VU", "desfavorable-malo": "EN", "desconocido": "DD"]
    static let parametro: [String: String] = ["range": "área de distribución", "population": "población", "habitat": "hábitat", "future": "perspectivas"]

    static let meses = ["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    static let mesesLargos = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    static let estadosPlanta = ["Adulto", "En flor", "Con fruto", "Plántula o juvenil", "Plantado o cultivado", "Seco o muerto"]
    static let estadosAnimal = ["Adulto", "Juvenil", "Cantando o llamando", "Cortejo o celo", "Con nido o crías", "Muerto"]

    private static let tipoSonidoTabla: [(String, String)] = [
        ("alarm call", "alarma"), ("flight call", "reclamo en vuelo"), ("begging call", "petición de comida"),
        ("song", "canto"), ("calls", "reclamo"), ("call", "reclamo"), ("echolocation", "ecolocalización"), ("social", "social"),
        ("drumming", "tamborileo"), ("female", "hembra"), ("male", "macho"), ("adult", "adulto"), ("juvenile", "juvenil"), ("near ", "cerca de "),
    ]
    /// Traduce los tipos de grabación de xeno-canto
    static func tipoSonido(_ t: String) -> String {
        var x = t
        for (en, es) in tipoSonidoTabla { x = x.replacingOccurrences(of: en, with: es) }
        return x
    }

    /// Partes de un nombre científico que no son epítetos
    static let rangos: Set<String> = ["subsp.", "var.", "f.", "×"]

    /// «Género especie» sin rangos ni subespecie
    static func binomio(_ nombre: String) -> String {
        nombre.split(separator: " ").map(String.init).filter { !rangos.contains($0) }.prefix(2).joined(separator: " ")
    }
}

// MARK: - Utilidades de texto

/// Minúsculas y sin tildes (igual que normalizar() en la web)
func normalizar(_ s: String) -> String {
    s.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
}

/// "HsPsTd" → [("H","s"), ("P","s"), ("T","d")]
func presencia(_ s: String) -> [String: String] {
    var out: [String: String] = [:]
    let c = Array(s)
    var i = 0
    while i + 1 < c.count {
        out[String(c[i])] = String(c[i + 1])
        i += 2
    }
    return out
}

/// Islas donde la especie está presente (sin «Mar» ni citas dudosas), en el orden de la cadena
func islasDe(_ s: String) -> [String] {
    var out: [String] = []
    let c = Array(s)
    var i = 0
    while i + 1 < c.count {
        let k = String(c[i]), v = String(c[i + 1])
        if k != "M" && v != "d" { out.append(k) }
        i += 2
    }
    return out
}

/// Números con separador de miles a la española (19.094; los de cuatro cifras sin punto)
func miles(_ n: Int) -> String {
    let s = String(abs(n))
    guard s.count > 4 else { return n < 0 ? "-" + s : s }
    var out = ""
    for (k, ch) in s.reversed().enumerated() {
        if k > 0 && k % 3 == 0 { out.append(".") }
        out.append(ch)
    }
    return (n < 0 ? "-" : "") + String(out.reversed())
}

/// Decimal con coma y como mucho `dec` decimales (1,5 · 12)
func decimal(_ d: Double, _ dec: Int = 1) -> String {
    let f = pow(10.0, Double(dec))
    let r = (d * f).rounded() / f
    if r == r.rounded() && abs(r) < 1e15 { return miles(Int(r)) }
    var s = String(format: "%.\(dec)f", r)
    while s.hasSuffix("0") { s.removeLast() }
    let partes = s.split(separator: ".")
    let ent = Int(partes[0]) ?? 0
    let entTxt = partes[0].hasPrefix("-") && ent == 0 ? "-0" : miles(ent)
    return partes.count > 1 ? "\(entTxt),\(partes[1])" : entTxt
}

/// Nº 0001
func numeroPokedex(_ no: Int) -> String {
    "Nº " + String(format: "%04d", no)
}

func conMayuscula(_ s: String) -> String {
    guard let p = s.first else { return s }
    return p.uppercased() + s.dropFirst()
}
