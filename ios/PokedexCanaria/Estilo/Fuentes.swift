import SwiftUI
import CoreText

/// Tipografías incluidas en la app (las mismas que la web, convertidas a TTF; licencias OFL en Recursos/Fuentes)
enum Fuentes {
    enum Peso: Int { case normal = 400, medio = 500, semi = 600, negrita = 700, extra = 800 }

    /// Caras disponibles de cada familia: (peso, cursiva) → nombre PostScript
    private static let caras: [String: [(Int, Bool, String)]] = [
        "Inter": [(400, false, "Inter-Regular"), (400, true, "Inter-Italic"), (600, false, "Inter-SemiBold"), (700, false, "Inter-Bold")],
        "Atkinson Hyperlegible": [(400, false, "AtkinsonHyperlegible-Regular"), (400, true, "AtkinsonHyperlegible-Italic"), (700, false, "AtkinsonHyperlegible-Bold")],
        "Fraunces": [(500, false, "Fraunces-Medium"), (400, true, "Fraunces-Italic")],
        "EB Garamond": [(400, false, "EBGaramond-Regular"), (400, true, "EBGaramond-Italic"), (500, false, "EBGaramond-Medium"), (600, false, "EBGaramond-SemiBold")],
        "Press Start 2P": [(400, false, "PressStart2P-Regular")],
        "VT323": [(400, false, "VT323-Regular")],
        "Caveat": [(500, false, "Caveat-Medium"), (600, false, "Caveat-SemiBold")],
    ]

    /// Nombre del ajuste «Tipo de letra» → familia
    static func familia(_ letra: String) -> String? {
        switch letra {
        case "Press Start 2P (píxel)": return "Press Start 2P"
        case "VT323 (LCD)": return "VT323"
        case "Sistema (San Francisco)": return nil
        default: return caras[letra] != nil ? letra : nil
        }
    }

    static func registrar() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fuentes") ?? [])
        for u in urls {
            CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
        }
    }

    /// Fuente de una familia con el peso y la cursiva más parecidos que haya
    static func fuente(_ letra: String, tam: CGFloat, peso: Peso = .normal, cursiva: Bool = false) -> Font {
        guard let fam = familia(letra), let lista = caras[fam] else {
            var f = Font.system(size: tam, weight: pesoSistema(peso))
            if cursiva { f = f.italic() }
            return f
        }
        let candidatas = lista.filter { $0.1 == cursiva }
        let elegibles = candidatas.isEmpty ? lista : candidatas
        let cara = elegibles.min { abs($0.0 - peso.rawValue) < abs($1.0 - peso.rawValue) }!
        var f = Font.custom(cara.2, size: tam, relativeTo: .body)
        // Si no hay cara del peso pedido, se refuerza un poco (no en letras de píxel)
        if peso.rawValue - cara.0 >= 200 && fam != "Press Start 2P" && fam != "VT323" { f = f.bold() }
        return f
    }

    private static func pesoSistema(_ p: Peso) -> Font.Weight {
        switch p {
        case .normal: return .regular
        case .medio: return .medium
        case .semi: return .semibold
        case .negrita: return .bold
        case .extra: return .heavy
        }
    }
}
