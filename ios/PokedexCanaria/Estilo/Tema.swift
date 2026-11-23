import SwiftUI
import UIKit

extension RGB {
    var color: Color { Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a) }
}

extension Color {
    init(hex: String) { self = RGB.hex(hex).color }

    /// #RRGGBB de un color de SwiftUI (para el selector de color propio)
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(Double(max(0, min(1, r))) * 255, Double(max(0, min(1, g))) * 255, Double(max(0, min(1, b))) * 255).hex
    }
}

/// Colores del texto según dónde esté (en el Pokédex, el texto sobre la carcasa y sobre la pantalla LCD es distinto)
struct Paleta {
    var texto: Color
    var texto2: Color
    var dentro: Bool
}

/// Aspecto de la app listo para usar en las vistas
struct Tema {
    let c: TemaCalculo

    init(_ c: TemaCalculo = TemaCalculo()) { self.c = c }

    var estilo: Estilo { c.estilo }
    var esPoke: Bool { c.estilo == .poke }
    var esCua: Bool { c.estilo == .cua }

    var acento: Color { c.acento.color }
    var acentoTxt: Color { c.acentoTxt.color }
    var acentoSuave: Color { c.acentoSuave.color }
    var acentoTinta: Color { c.acentoTinta.color }
    var fondo: Color { c.fondo.color }
    var superficie: Color { c.superficie.color }
    var superficie2: Color { c.superficie2.color }
    var texto: Color { c.texto.color }
    var texto2: Color { c.texto2.color }
    var borde: Color { c.borde.color }
    var borde2: Color { c.borde2.color }
    var peligro: Color { c.peligro.color }
    var carcasa: Color { c.carcasa.color }
    var carcasaTxt: Color { c.carcasaTxt.color }
    var tecla: Color { c.tecla.color }
    var oscuroPoke: Color { Color(hex: "#2B2B2B") }
    /// Fondo de toda la pantalla (en el Pokédex, la carcasa)
    var fondoPantalla: Color { esPoke ? carcasa : fondo }

    /// Texto fuera de las tarjetas
    var fuera: Paleta { Paleta(texto: esPoke ? c.carcasaTxt.color : texto, texto2: esPoke ? c.carcasaTexto2.color : texto2, dentro: false) }
    /// Texto dentro de las tarjetas
    var dentro: Paleta { Paleta(texto: texto, texto2: texto2, dentro: true) }

    // Medidas
    var radio: CGFloat { CGFloat(c.radio) }
    var radioP: CGFloat { CGFloat(c.radioP) }
    var esp: CGFloat { CGFloat(c.esp) }
    var tam: CGFloat { CGFloat(c.tamBase) }
    var margen: CGFloat { 18 * esp }
    var hueco: CGFloat { 18 * esp }
    var animacion: Animation? { c.anim > 0 ? .easeOut(duration: c.anim) : nil }

    enum Familia { case principal, titulo, cientifico, pixel, lcd, mano, garamond, inter }

    /// Letra a `em` veces el tamaño base del texto
    func f(_ em: CGFloat = 1, _ peso: Fuentes.Peso = .normal, _ familia: Familia = .principal, cursiva: Bool = false) -> Font {
        let base = tam * em
        switch familia {
        case .principal: return Fuentes.fuente(c.letra, tam: base, peso: peso, cursiva: cursiva)
        case .titulo: return Fuentes.fuente(c.letraTitulo, tam: base, peso: peso, cursiva: cursiva)
        case .cientifico: return Fuentes.fuente(c.letraCientifico, tam: base, peso: peso, cursiva: cursiva && c.cientificoCursiva)
        case .pixel: return Fuentes.fuente("Press Start 2P", tam: base, peso: peso)
        case .lcd: return Fuentes.fuente("VT323", tam: base, peso: peso)
        case .mano: return Fuentes.fuente("Caveat", tam: base, peso: peso)
        case .garamond: return Fuentes.fuente("EB Garamond", tam: base, peso: peso, cursiva: cursiva)
        case .inter: return Fuentes.fuente("Inter", tam: base, peso: peso, cursiva: cursiva)
        }
    }

    /// Letra con tamaño fijo en puntos (para dibujos)
    func fPuntos(_ pt: CGFloat, _ peso: Fuentes.Peso = .normal) -> Font {
        Fuentes.fuente(c.letra.hasPrefix("Press") ? "Inter" : c.letra, tam: pt, peso: peso)
    }
}

private struct ClaveTema: EnvironmentKey { static let defaultValue = Tema() }
private struct ClavePaleta: EnvironmentKey {
    static let defaultValue = Paleta(texto: Color(hex: "#1C211B"), texto2: Color(hex: "#5A6158"), dentro: false)
}

extension EnvironmentValues {
    var tema: Tema {
        get { self[ClaveTema.self] }
        set { self[ClaveTema.self] = newValue }
    }
    var paleta: Paleta {
        get { self[ClavePaleta.self] }
        set { self[ClavePaleta.self] = newValue }
    }
}
