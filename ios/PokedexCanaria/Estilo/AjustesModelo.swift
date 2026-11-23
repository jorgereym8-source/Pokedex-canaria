import Foundation

/// Los tres estilos de la app
enum Estilo: String, Codable, CaseIterable, Identifiable {
    case nat, poke, cua
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .nat: return "Naturalista"
        case .poke: return "Pokédex"
        case .cua: return "Cuaderno"
        }
    }
}

/// Una opción personalizable de cada estilo (los menús desplegables de Ajustes)
struct OpcionEstilo: Identifiable {
    let id: String
    let etiquetas: [Estilo: String]
    let opciones: [Estilo: [String]]
    let porDefecto: [Estilo: String]

    func etiqueta(_ e: Estilo) -> String { etiquetas[e] ?? etiquetas[.nat] ?? id }
    func valores(_ e: Estilo) -> [String] { opciones[e] ?? opciones[.nat] ?? [] }

    init(_ id: String, _ etiqueta: String, _ opciones: [String], def: [Estilo: String]) {
        self.id = id
        etiquetas = [.nat: etiqueta, .poke: etiqueta, .cua: etiqueta]
        self.opciones = [.nat: opciones, .poke: opciones, .cua: opciones]
        porDefecto = def
    }

    init(_ id: String, etiquetas: [Estilo: String], opciones: [Estilo: [String]], def: [Estilo: String]) {
        self.id = id
        self.etiquetas = etiquetas
        self.opciones = opciones
        porDefecto = def
    }
}

enum Paletas {
    static let color: [String: String] = [
        // Naturalista
        "Verde cardón": "#3D6B35", "Azul océano": "#2D6A8F", "Rojo tajinaste": "#B23A2E", "Ocre malpaís": "#9A6B12",
        "Violeta del Teide": "#6E4C8C", "Negro basalto": "#2A2D2B",
        "Arena clara": "#F4F5F1", "Blanco": "#FFFFFF", "Gris niebla": "#E9ECE7", "Noche volcánica": "#141816",
        // Pokédex
        "Rojo clásico": "#C3262F", "Azul": "#1F5FA8", "Amarillo": "#E3B21B", "Verde": "#2E6B2F", "Negro": "#2B2B2B",
        "Pantalla LCD verde": "#C9DDB8", "LCD ámbar": "#F2C46D", "LCD azul": "#B9D4EC", "LCD negra": "#17230F",
        // Cuaderno
        "Tinta azul": "#2D4A6B", "Tinta sepia": "#6B4A2B", "Tinta negra": "#2A2620", "Tinta verde": "#3E5A3A",
        "Papel crema": "#F2EBDC", "Papel blanco": "#FBFAF6", "Kraft": "#D9C4A0", "Papel oscuro": "#2E2A24",
    ]

    static let letras = ["Sistema (San Francisco)", "Inter", "Atkinson Hyperlegible", "Fraunces", "EB Garamond", "Press Start 2P (píxel)", "VT323 (LCD)"]

    /// Algunas letras se ven más pequeñas o más grandes de lo normal: se compensan
    static let escalaLetra: [String: Double] = ["VT323 (LCD)": 1.25, "Press Start 2P (píxel)": 0.72, "EB Garamond": 1.08, "Caveat": 1.2]

    static let opciones: [OpcionEstilo] = [
        OpcionEstilo("tema", "Tema", ["Automático", "Claro", "Oscuro", "Según la hora del día"],
                     def: [.nat: "Automático", .poke: "Automático", .cua: "Claro"]),
        OpcionEstilo("color",
                     etiquetas: [.nat: "Color principal", .poke: "Color de la carcasa", .cua: "Color de la tinta"],
                     opciones: [.nat: ["Verde cardón", "Azul océano", "Rojo tajinaste", "Ocre malpaís", "Violeta del Teide", "Negro basalto", "Personalizado"],
                                .poke: ["Rojo clásico", "Azul", "Amarillo", "Verde", "Negro", "Personalizado"],
                                .cua: ["Tinta azul", "Tinta sepia", "Tinta negra", "Tinta verde", "Personalizado"]],
                     def: [.nat: "Verde cardón", .poke: "Rojo clásico", .cua: "Tinta azul"]),
        OpcionEstilo("fondo",
                     etiquetas: [.nat: "Color de fondo", .poke: "Color de la pantalla", .cua: "Papel"],
                     opciones: [.nat: ["Arena clara", "Blanco", "Gris niebla", "Noche volcánica"],
                                .poke: ["Pantalla LCD verde", "LCD ámbar", "LCD azul", "LCD negra"],
                                .cua: ["Papel crema", "Papel blanco", "Kraft", "Papel oscuro"]],
                     def: [.nat: "Arena clara", .poke: "Pantalla LCD verde", .cua: "Papel crema"]),
        OpcionEstilo("letra", "Tipo de letra", letras, def: [.nat: "Inter", .poke: "VT323 (LCD)", .cua: "EB Garamond"]),
        OpcionEstilo("cient", "Nombres científicos", ["Cursiva de la misma letra", "Cursiva con serifa", "Sin cursiva"],
                     def: [.nat: "Cursiva de la misma letra", .poke: "Cursiva de la misma letra", .cua: "Cursiva con serifa"]),
        OpcionEstilo("tam", "Tamaño del texto", ["Pequeño", "Normal", "Grande", "Muy grande"], def: [.nat: "Normal", .poke: "Normal", .cua: "Normal"]),
        OpcionEstilo("forma", "Forma de las tarjetas", ["Redondeada", "Suave", "Recta"], def: [.nat: "Redondeada", .poke: "Recta", .cua: "Recta"]),
        OpcionEstilo("dens", "Densidad", ["Compacta", "Cómoda", "Amplia"], def: [.nat: "Cómoda", .poke: "Compacta", .cua: "Amplia"]),
        OpcionEstilo("transp", "Fondos y transparencias", ["Liso", "Translúcido", "Textura de papel", "Malla de puntos"],
                     def: [.nat: "Translúcido", .poke: "Liso", .cua: "Textura de papel"]),
        OpcionEstilo("iconos", "Iconos", ["Línea fina", "Línea gruesa", "Píxel"], def: [.nat: "Línea fina", .poke: "Píxel", .cua: "Línea fina"]),
        OpcionEstilo("anim", "Animaciones", ["Normales", "Reducidas", "Ninguna"], def: [.nat: "Normales", .poke: "Normales", .cua: "Reducidas"]),
    ]

    static func opcion(_ id: String) -> OpcionEstilo? { opciones.first { $0.id == id } }
}

/// Ajustes guardados (mismo contenido que en la web, que los guarda en localStorage)
struct DatosAjustes: Codable, Equatable {
    var estilo: Estilo = .nat
    var porEstilo: [String: [String: String]] = ["nat": [:], "poke": [:], "cua": [:]]
    var personalizado: [String: String] = ["nat": "#3D6B35", "poke": "#C3262F", "cua": "#2D4A6B"]
    var nombres = "Todos"                    // Todos | Solo el principal
    var autoria = true                       // autoría del nombre científico
    var numeracion = "Taxonómica"            // Taxonómica | Nombre común | Nombre científico
    var altura = 180                         // cm, para el diagrama de tamaño
    var guardarLugar = true
    var precision = "Aprox. si amenazada"    // Exacta | Aprox. si amenazada | Siempre aprox.
    var guardarTiempo = true
    var fotosBiota = true
    var fotosLibres = true

    init() {}

    enum CodingKeys: String, CodingKey {
        case estilo, porEstilo, personalizado, nombres, autoria, numeracion, altura, guardarLugar, precision, guardarTiempo, fotosBiota, fotosLibres
    }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        let d = DatosAjustes()
        estilo = (try? k.decodeIfPresent(Estilo.self, forKey: .estilo)) ?? d.estilo
        porEstilo = d.porEstilo.merging((try? k.decodeIfPresent([String: [String: String]].self, forKey: .porEstilo)) ?? [:]) { $1 }
        personalizado = d.personalizado.merging((try? k.decodeIfPresent([String: String].self, forKey: .personalizado)) ?? [:]) { $1 }
        nombres = (try? k.decodeIfPresent(String.self, forKey: .nombres)) ?? d.nombres
        autoria = (try? k.decodeIfPresent(Bool.self, forKey: .autoria)) ?? d.autoria
        numeracion = (try? k.decodeIfPresent(String.self, forKey: .numeracion)) ?? d.numeracion
        altura = (try? k.decodeIfPresent(Int.self, forKey: .altura)) ?? d.altura
        guardarLugar = (try? k.decodeIfPresent(Bool.self, forKey: .guardarLugar)) ?? d.guardarLugar
        precision = (try? k.decodeIfPresent(String.self, forKey: .precision)) ?? d.precision
        guardarTiempo = (try? k.decodeIfPresent(Bool.self, forKey: .guardarTiempo)) ?? d.guardarTiempo
        fotosBiota = (try? k.decodeIfPresent(Bool.self, forKey: .fotosBiota)) ?? d.fotosBiota
        fotosLibres = (try? k.decodeIfPresent(Bool.self, forKey: .fotosLibres)) ?? d.fotosLibres
    }

    /// Valor de una opción del estilo actual (o su valor por defecto)
    func valor(_ id: String) -> String {
        if let v = porEstilo[estilo.rawValue]?[id], !v.isEmpty { return v }
        return Paletas.opcion(id)?.porDefecto[estilo] ?? ""
    }

    mutating func fijar(_ id: String, _ v: String) {
        var d = porEstilo[estilo.rawValue] ?? [:]
        d[id] = v
        porEstilo[estilo.rawValue] = d
    }

    mutating func restablecer() { porEstilo[estilo.rawValue] = [:] }

    func colorDe(_ nombre: String) -> String? {
        if nombre == "Personalizado" { return personalizado[estilo.rawValue] }
        return Paletas.color[nombre]
    }

    mutating func fijarPersonalizado(_ hex: String) {
        personalizado[estilo.rawValue] = hex
        fijar("color", "Personalizado")
    }
}
