import Foundation

/// Color RGB (0-255) con las mismas operaciones que js/ajustes.js
struct RGB: Equatable {
    var r: Double, g: Double, b: Double, a: Double = 1

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        r = Double((v >> 16) & 0xFF); g = Double((v >> 8) & 0xFF); b = Double(v & 0xFF)
    }

    static func hex(_ s: String) -> RGB { RGB(hex: s) ?? RGB(0, 0, 0) }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(r.rounded()), Int(g.rounded()), Int(b.rounded()))
    }

    var luminancia: Double {
        func canal(_ c: Double) -> Double {
            let x = c / 255
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)
    }

    static func contraste(_ a: RGB, _ b: RGB) -> Double {
        let x = max(a.luminancia, b.luminancia), y = min(a.luminancia, b.luminancia)
        return (x + 0.05) / (y + 0.05)
    }

    /// Texto legible sobre este color
    var textoSobre: RGB { RGB.contraste(self, RGB(255, 255, 255)) >= 4.5 ? RGB(255, 255, 255) : RGB.hex("#17201A") }

    /// Mezcla: t = 0 → este color, t = 1 → el otro
    func mezclar(_ o: RGB, _ t: Double) -> RGB {
        RGB((r * (1 - t) + o.r * t).rounded(), (g * (1 - t) + o.g * t).rounded(), (b * (1 - t) + o.b * t).rounded())
    }

    var esOscuro: Bool { luminancia < 0.2 }

    static let blanco = RGB(255, 255, 255)
    static let negro = RGB(0, 0, 0)
}

/// Todo lo que define el aspecto de la app para el estilo y los ajustes actuales
/// (equivale a las variables CSS que calcula aplicar() en la web)
struct TemaCalculo: Equatable {
    var estilo: Estilo = .nat
    var oscuro = false

    // Colores
    var acento = RGB.hex("#3D6B35")
    var acentoTxt = RGB.blanco
    var acentoSuave = RGB.hex("#E1ECDB")
    var acentoTinta = RGB.hex("#24461F")
    var fondo = RGB.hex("#F4F5F1")
    var superficie = RGB.blanco
    var superficie2 = RGB.hex("#EEF0EA")
    var texto = RGB.hex("#1C211B")
    var texto2 = RGB.hex("#5A6158")
    var borde = RGB.hex("#E1E4DC")
    var borde2 = RGB.hex("#EEF0EA")
    var barraFondo = RGB(255, 255, 255, 0.94)
    var peligro = RGB.hex("#B3261E")
    // Solo Pokédex: carcasa (color principal) y textos sobre ella
    var carcasa = RGB.hex("#C3262F")
    var carcasaTxt = RGB.blanco
    var carcasaTexto2 = RGB.blanco
    var tecla = RGB.hex("#1F5FA8")
    var lcdTexto2 = RGB.hex("#5A6158")

    // Letra y formas
    var letra = "Inter"
    var letraTitulo = "Inter"
    var letraCientifico = "Inter"
    var cientificoCursiva = true
    var tamBase: Double = 16
    var radio: Double = 18
    var radioP: Double = 10
    var esp: Double = 1
    var trazo: Double = 1.7
    var trazoCuadrado = false
    var anim: Double = 0.22
    var translucido = true
    var textura = "Liso"   // Liso | Translúcido | Textura de papel | Malla de puntos

    static func calcular(_ d: DatosAjustes, sistemaOscuro: Bool, hora: Int) -> TemaCalculo {
        var t = TemaCalculo()
        let e = d.estilo
        t.estilo = e
        let tema = d.valor("tema")
        switch tema {
        case "Oscuro": t.oscuro = true
        case "Claro": t.oscuro = false
        case "Según la hora del día": t.oscuro = hora >= 20 || hora < 7
        default: t.oscuro = sistemaOscuro
        }
        var acento = RGB.hex(d.colorDe(d.valor("color")) ?? "#3D6B35")
        var fondo = RGB.hex(Paletas.color[d.valor("fondo")] ?? "#F4F5F1")
        if t.oscuro && !fondo.esOscuro {
            fondo = RGB.hex(["nat": "#141816", "poke": "#17230F", "cua": "#2E2A24"][e.rawValue] ?? "#141816")
        }
        let fondoOscuro = fondo.esOscuro

        if e == .poke {
            // La carcasa usa el color principal; la pantalla LCD es el fondo de los paneles
            let tabla: [String: String] = ["#C9DDB8": "#17230F", "#F2C46D": "#3A2600", "#B9D4EC": "#0E2236", "#17230F": "#9BE07A"]
            let lcdTexto = RGB.hex(tabla[fondo.hex] ?? (fondoOscuro ? "#9BE07A" : "#17230F"))
            let carcasa = t.oscuro ? acento.mezclar(.negro, 0.45) : acento
            t.carcasa = carcasa
            t.carcasaTxt = carcasa.textoSobre
            t.carcasaTexto2 = carcasa.textoSobre.mezclar(carcasa, 0.18)
            t.tecla = RGB.hex("#1F5FA8")
            t.fondo = fondo
            t.superficie = fondo
            t.superficie2 = fondo.mezclar(lcdTexto, 0.12)
            t.texto = lcdTexto
            t.lcdTexto2 = lcdTexto.mezclar(fondo, 0.3)
            t.texto2 = t.lcdTexto2
            t.borde = RGB.hex("#2B2B2B")
            t.borde2 = fondo.mezclar(lcdTexto, 0.25)
            t.acento = lcdTexto
            t.acentoTxt = fondo
            t.acentoSuave = fondo.mezclar(lcdTexto, 0.15)
            t.acentoTinta = lcdTexto
            t.barraFondo = RGB.hex("#2B2B2B")
        } else {
            let texto = fondoOscuro ? RGB.hex(e == .cua ? "#EDE4D3" : "#EEF1EC") : RGB.hex(e == .cua ? "#2A2620" : "#1C211B")
            if fondoOscuro && RGB.contraste(acento, fondo) < 3 { acento = acento.mezclar(.blanco, 0.45) }
            t.acento = acento
            t.acentoTxt = acento.textoSobre
            t.acentoSuave = fondoOscuro ? fondo.mezclar(acento, 0.28) : RGB.blanco.mezclar(acento, 0.16)
            t.acentoTinta = fondoOscuro ? acento.mezclar(.blanco, 0.55) : acento.mezclar(.negro, 0.35)
            t.fondo = fondo
            t.superficie = e == .cua ? fondo : (fondoOscuro ? fondo.mezclar(.blanco, 0.06) : .blanco)
            t.superficie2 = fondoOscuro ? fondo.mezclar(.blanco, 0.1) : fondo.mezclar(.negro, 0.035)
            t.texto = texto
            t.texto2 = texto.mezclar(fondo, 0.38)
            t.borde = e == .cua ? texto.mezclar(fondo, 0.7) : (fondoOscuro ? fondo.mezclar(.blanco, 0.14) : fondo.mezclar(.negro, 0.08))
            t.borde2 = fondoOscuro ? fondo.mezclar(.blanco, 0.09) : fondo.mezclar(.negro, 0.04)
            t.barraFondo = fondoOscuro ? RGB(20, 24, 22, 0.92) : RGB(255, 255, 255, 0.94)
            t.carcasa = fondo
            t.carcasaTxt = texto
            t.carcasaTexto2 = t.texto2
            t.lcdTexto2 = t.texto2
        }
        if fondoOscuro { t.peligro = RGB.hex("#FF8A80") }

        let letra = d.valor("letra")
        t.letra = Paletas.letras.contains(letra) ? letra : "Inter"
        t.letraTitulo = e == .cua ? "EB Garamond" : t.letra
        let cient = d.valor("cient")
        t.letraCientifico = cient == "Cursiva con serifa" ? "EB Garamond" : (t.letra.hasPrefix("Press") ? "Inter" : t.letra)
        t.cientificoCursiva = cient != "Sin cursiva"
        let base: Double = ["Pequeño": 15, "Normal": 16, "Grande": 18, "Muy grande": 20][d.valor("tam")] ?? 16
        t.tamBase = (base * (Paletas.escalaLetra[t.letra] ?? 1)).rounded()
        t.radio = ["Redondeada": 18, "Suave": 8, "Recta": 0][d.valor("forma")] ?? 18
        t.radioP = ["Redondeada": 10, "Suave": 5, "Recta": 0][d.valor("forma")] ?? 10
        t.esp = ["Compacta": 0.75, "Cómoda": 1, "Amplia": 1.25][d.valor("dens")] ?? 1
        let iconos = d.valor("iconos")
        t.trazo = ["Línea fina": 1.7, "Línea gruesa": 2.4, "Píxel": 2.6][iconos] ?? 1.7
        t.trazoCuadrado = iconos == "Píxel"
        t.anim = ["Normales": 0.22, "Reducidas": 0.08, "Ninguna": 0][d.valor("anim")] ?? 0.22
        let transp = d.valor("transp")
        t.translucido = transp == "Translúcido"
        t.textura = transp
        return t
    }
}
