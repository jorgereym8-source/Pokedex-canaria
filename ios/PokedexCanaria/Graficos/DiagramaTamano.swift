import SwiftUI

struct Silueta {
    let w: Double
    let h: Double
    /// Las verticales (plantas, personas) se escalan por altura; el resto (animales), por longitud
    let vertical: Bool
    let d: String
}

/// Diagrama de tamaño: la especie a escala junto a tu silueta (o una mano o una moneda, si es pequeña)
struct DiagramaTamano: View {
    let forma: String
    let min: Double?
    let max: Double
    let alturaCm: Int
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    private static let alias = ["árbol": "arbol", "trepadora": "arbusto", "planta": "arbusto", "raya": "pez"]

    var body: some View {
        // Copias locales: el dibujo no lee nada de la vista
        let tema = self.tema
        let p = self.p
        let forma = self.forma
        let min = self.min
        let max = self.max
        let alturaCm = self.alturaCm
        Canvas { ctx, size in
            let W = 340.0, alto = 230.0
            let k = CGFloat(Double(size.width) / W)
            ctx.scaleBy(x: k, y: k)
            let sil = Siluetas.tabla[DiagramaTamano.alias[forma] ?? forma] ?? Siluetas.tabla["arbusto"]!
            let t = max
            let ancho = sil.vertical ? t * sil.w / sil.h : t
            let altoEsp = sil.vertical ? t : t * sil.h / sil.w
            let conMoneda = t < 0.03, conMano = t < 0.3
            let ref = conMoneda ? Siluetas.tabla["moneda"]! : conMano ? Siluetas.tabla["mano"]! : Siluetas.tabla["humano"]!
            let refAlto = conMoneda ? 0.02325 : conMano ? 0.19 : Double(alturaCm) / 100
            let refAncho = refAlto * ref.w / ref.h

            let suelo = 196.0, izq = 18.0, der = 18.0, arriba = 34.0
            let hueco = Swift.max(refAncho, ancho) * 0.3
            let escala = Swift.min((W - izq - der) / (refAncho + hueco + ancho), (suelo - arriba) / Swift.max(refAlto, altoEsp))
            let xRef = izq + ((W - izq - der) - (refAncho + hueco + ancho) * escala) / 2
            let xEsp = xRef + (refAncho + hueco) * escala
            let kRef = (refAncho * escala) / ref.w, kEsp = (ancho * escala) / sil.w
            let hRef = refAlto * escala, hEsp = altoEsp * escala
            let barra = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20].first { $0 * escala >= 36 } ?? 20
            let etRef = conMoneda ? "Moneda de 1 €" : conMano ? "Mano · \(Medidas.medida(refAlto))" : "Tú · \(Medidas.medida(refAlto))"
            let etEsp = Medidas.textoTamano(min: min, max: max)
            let colorTexto = p.texto, colorTexto2 = p.texto2
            let colorAcento = tema.esPoke ? p.texto : tema.acento

            // suelo
            var linea = Path()
            linea.move(to: CGPoint(x: 6, y: suelo))
            linea.addLine(to: CGPoint(x: W - 6, y: suelo))
            ctx.stroke(linea, with: .color(tema.esPoke ? colorTexto2 : tema.borde), lineWidth: 1.5)

            // siluetas
            let pr = Path(svg: ref.d).applying(CGAffineTransform(a: kRef, b: 0, c: 0, d: kRef, tx: xRef, ty: suelo - hRef))
            ctx.fill(pr, with: .color(colorTexto.opacity(0.85)))
            let pe = Path(svg: sil.d).applying(CGAffineTransform(a: kEsp, b: 0, c: 0, d: kEsp, tx: xEsp, ty: suelo - hEsp))
            ctx.fill(pe, with: .color(colorAcento))

            // etiquetas que no se salen por los bordes
            func etiqueta(_ x: Double, _ y: Double, _ texto: String, _ tam: CGFloat, _ peso: Fuentes.Peso, _ color: Color) {
                let r = ctx.resolve(Text(texto).font(tema.fPuntos(tam, peso)).foregroundColor(color))
                let w = Double(r.measure(in: CGSize(width: 1000, height: 100)).width)
                var xx = x, ancla = UnitPoint.bottom
                if x - w / 2 < 4 { xx = 4; ancla = .bottomLeading } else if x + w / 2 > W - 4 { xx = W - 4; ancla = .bottomTrailing }
                ctx.draw(r, at: CGPoint(x: xx, y: y + 3), anchor: ancla)
            }
            etiqueta(xRef + (refAncho * escala) / 2, suelo - hRef - 8, etRef, 11, .semi, colorTexto)
            etiqueta(xEsp + (ancho * escala) / 2, Swift.max(14, suelo - hEsp - 8), etEsp, 12, .negrita, colorAcento)

            // barra de escala
            var b = Path()
            b.move(to: CGPoint(x: W - 18 - barra * escala, y: 216)); b.addLine(to: CGPoint(x: W - 18, y: 216))
            b.move(to: CGPoint(x: W - 18 - barra * escala, y: 211)); b.addLine(to: CGPoint(x: W - 18 - barra * escala, y: 221))
            b.move(to: CGPoint(x: W - 18, y: 211)); b.addLine(to: CGPoint(x: W - 18, y: 221))
            ctx.stroke(b, with: .color(colorTexto2), lineWidth: 1.8)
            let rb = ctx.resolve(Text(Medidas.medida(barra)).font(tema.fPuntos(10)).foregroundColor(colorTexto2))
            ctx.draw(rb, at: CGPoint(x: W - 18 - (barra * escala) / 2, y: 211), anchor: .bottom)
            _ = alto
        }
        .aspectRatio(340.0 / 230.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Comparación de tamaño: \(Medidas.textoTamano(min: min, max: max))")
    }
}

enum Siluetas {
    static let tabla: [String: Silueta] = [
        "humano": Silueta(w: 40, h: 100, vertical: true, d: "M12 8a8 8 0 1 0 16 0a8 8 0 1 0-16 0zM8 20Q20 17 32 20L38 54 34 55 29 30 29 100 23 100 21 60 19 60 17 100 11 100 11 30 6 55 2 54Z"),
        "moneda": Silueta(w: 100, h: 100, vertical: true, d: "M50 0a50 50 0 1 0 0.01 0ZM50 10a40 40 0 1 1-0.01 0Z"),
        "mano": Silueta(w: 50, h: 100, vertical: true, d: "M10 100L10 52Q8 40 10 34L12 14Q14 10 17 14L18 40 20 6Q22 2 25 6L26 40 28 4Q30 0 33 4L34 42 36 12Q38 8 41 12L42 52 48 40Q52 38 50 44L42 70Q40 84 38 100Z"),
        "arbol": Silueta(w: 100, h: 110, vertical: true, d: "M45 110L45 66Q30 68 16 60Q0 50 6 34Q10 16 30 14Q38 2 56 4Q76 2 86 18Q100 30 94 46Q90 62 70 64Q62 66 55 66L55 110Z"),
        "palmera": Silueta(w: 80, h: 120, vertical: true, d: "M38 120Q35 80 40 30L44 30Q41 80 44 120ZM42 28Q22 14 0 32Q22 22 41 31ZM42 28Q62 12 80 30Q60 22 43 31ZM42 28Q34 6 14 6Q32 12 41 30ZM42 28Q52 4 72 8Q54 12 43 30ZM42 28Q34 40 16 56Q32 40 41 31ZM42 28Q52 40 68 56Q52 40 43 31Z"),
        "arbusto": Silueta(w: 120, h: 80, vertical: true, d: "M4 80Q0 56 16 48Q16 26 40 26Q50 8 72 16Q92 12 100 32Q118 38 116 58Q120 70 116 80Z"),
        "hierba": Silueta(w: 70, h: 100, vertical: true, d: "M33 100Q24 62 4 44Q28 58 37 100ZM37 100Q42 56 62 38Q48 62 41 100ZM34 100Q33 50 35 18Q38 50 38 100ZM28 12a7 7 0 1 0 14 0a7 7 0 1 0-14 0Z"),
        "roseta": Silueta(w: 60, h: 120, vertical: true, d: "M20 98Q26 50 30 2Q34 50 40 98ZM30 120Q12 116 0 106Q18 104 28 110ZM30 120Q48 116 60 106Q42 104 32 110ZM30 120Q20 108 14 96Q26 102 30 114ZM30 120Q40 108 46 96Q34 102 30 114ZM28 120L28 98L32 98L32 120Z"),
        "cactiforme": Silueta(w: 146, h: 100, vertical: true, d: "M4 100V61Q4 55 10 55Q16 55 16 61V100ZM18 100V34Q18 28 24 28Q30 28 30 34V100ZM32 100V16Q32 10 38 10Q44 10 44 16V100ZM46 100V6Q46 0 52 0Q58 0 58 6V100ZM60 100V24Q60 18 66 18Q72 18 72 24V100ZM74 100V10Q74 4 80 4Q86 4 86 10V100ZM88 100V36Q88 30 94 30Q100 30 100 36V100ZM102 100V20Q102 14 108 14Q114 14 114 20V100ZM116 100V46Q116 40 122 40Q128 40 128 46V100ZM130 100V64Q130 58 136 58Q142 58 142 64V100Z"),
        "helecho": Silueta(w: 100, h: 80, vertical: true, d: "M50 80Q30 50 2 44Q30 40 52 76ZM50 80Q70 50 98 44Q70 40 48 76ZM50 80Q36 40 22 8Q46 36 53 78ZM50 80Q64 40 78 8Q54 36 47 78ZM49 80Q50 40 50 0Q52 40 51 80Z"),
        "ave": Silueta(w: 100, h: 70, vertical: false, d: "M8 40Q20 28 44 26Q58 16 70 14Q84 12 88 22L98 25L88 29Q86 40 76 48Q62 60 40 58Q22 54 14 48L0 46ZM46 57L44 70L47 70L49 57ZM56 56L56 70L59 70L59 56Z"),
        "lagarto": Silueta(w: 100, h: 24, vertical: false, d: "M0 14Q20 12 40 10Q50 4 62 6L82 6Q96 6 100 10Q96 14 82 14L66 14L70 22L66 22L60 15L46 15L44 22L40 22L40 15Q20 16 0 14ZM72 6L76 0L79 0L77 6ZM48 9L50 2L53 2L52 9Z"),
        "serpiente": Silueta(w: 100, h: 14, vertical: false, d: "M0 9Q12 0 25 7T50 7T75 7Q86 12 94 6L100 7L94 9Q86 15 75 10T50 10T25 10Q12 4 0 11Z"),
        "tortuga": Silueta(w: 100, h: 40, vertical: false, d: "M14 32Q16 6 50 4Q84 6 86 32ZM84 24Q94 18 100 24Q96 30 86 30ZM20 32L8 40L28 36ZM72 32L84 40L66 36Z"),
        "pez": Silueta(w: 100, h: 36, vertical: false, d: "M0 6L16 18L0 30L6 18ZM14 18Q34 0 62 2Q86 4 100 18Q86 32 62 34Q34 36 14 18Z"),
        "tiburon": Silueta(w: 100, h: 30, vertical: false, d: "M0 2L12 15L4 28L18 17Q40 8 60 8L66 0L72 8Q90 10 100 16Q90 22 70 22L64 28L60 22Q38 24 18 17Z"),
        "cetaceo": Silueta(w: 100, h: 26, vertical: false, d: "M0 4L8 13L0 22L12 15Q34 6 60 6L64 0L70 7Q88 9 94 13L100 14L94 16Q84 22 60 22Q34 22 12 15Z"),
        "murcielago": Silueta(w: 100, h: 45, vertical: false, d: "M50 14L46 6L48 14Q40 16 36 24Q24 10 0 14Q10 22 8 34Q18 28 24 36Q30 30 38 34Q44 40 50 42Q56 40 62 34Q70 30 76 36Q82 28 92 34Q90 22 100 14Q76 10 64 24Q60 16 52 14L54 6Z"),
        "mamifero": Silueta(w: 100, h: 60, vertical: false, d: "M10 20Q8 8 16 6L18 0L22 6Q28 10 26 20Q50 16 76 18Q92 18 96 30L100 38L94 36Q92 40 88 42L88 60L82 60L80 42L36 42L34 60L28 60L26 40Q14 34 10 20Z"),
        "rana": Silueta(w: 100, h: 60, vertical: false, d: "M20 60Q2 56 10 44Q14 30 30 24Q32 10 44 12Q50 4 58 12Q72 10 72 24Q90 30 92 44Q98 56 80 60Q72 50 64 54L58 60L42 60L36 54Q28 50 20 60Z"),
        "escarabajo": Silueta(w: 100, h: 50, vertical: false, d: "M18 30Q20 8 56 6Q90 8 92 28Q92 36 84 38L20 38Q16 36 18 30ZM8 30Q8 22 18 22L18 34Q8 36 8 30ZM26 38L20 50L24 50L32 38ZM50 38L48 50L52 50L56 38ZM74 38L80 50L84 50L80 38ZM4 26L0 18L2 17L8 24Z"),
        "mariposa": Silueta(w: 100, h: 70, vertical: false, d: "M50 18Q46 40 50 66Q54 40 50 18ZM48 26Q30 0 8 4Q0 18 12 32Q2 46 16 58Q30 62 46 42ZM52 26Q70 0 92 4Q100 18 88 32Q98 46 84 58Q70 62 54 42ZM49 18L42 4L44 3L50 16ZM51 18L58 4L56 3L50 16Z"),
        "libelula": Silueta(w: 100, h: 60, vertical: false, d: "M2 30Q4 25 12 26L96 29Q100 30 96 31L12 34Q4 35 2 30ZM16 28Q22 4 44 2Q40 16 22 30ZM16 32Q22 56 44 58Q40 44 22 30ZM26 28Q40 8 62 10Q54 22 30 30ZM26 32Q40 52 62 50Q54 38 30 30Z"),
        "saltamontes": Silueta(w: 100, h: 50, vertical: false, d: "M6 24Q8 14 20 14L70 16Q96 18 98 26Q96 32 70 32L20 32Q8 32 6 24ZM40 18Q60 0 90 6L90 10Q62 8 44 22ZM60 30L82 12L86 14L64 32L66 48L62 48L60 32ZM28 32L24 48L28 48L32 32ZM44 32L42 48L46 48L48 32ZM6 20L0 4L2 3L9 18Z"),
        "hormiga": Silueta(w: 100, h: 40, vertical: false, d: "M4 16a8 7 0 1 0 16 0a8 7 0 1 0-16 0ZM22 18Q30 10 40 14Q44 18 40 22Q30 24 22 18ZM48 18a20 12 0 1 0 40 0a20 12 0 1 0-40 0ZM28 22L20 38L23 39L31 23ZM34 22L34 40L37 40L37 22ZM40 20L50 38L47 39L38 22ZM8 10L2 0L4 0L11 9Z"),
        "mosca": Silueta(w: 100, h: 60, vertical: false, d: "M22 30a8 8 0 1 0 16 0a8 8 0 1 0-16 0ZM38 30Q38 22 48 22Q86 24 90 30Q86 36 48 38Q38 38 38 30ZM44 26Q56 4 82 2Q84 14 56 28ZM44 34Q56 56 82 58Q84 46 56 32Z"),
        "arana": Silueta(w: 100, h: 72, vertical: false, d: "M40 32a10 10 0 1 0 20 0a10 10 0 1 0-20 0ZM36 52a14 14 0 1 0 28 0a14 14 0 1 0-28 0ZM42 30L16 6L13 8L40 33ZM41 35L4 26L4 29L40 38ZM42 40L6 56L8 59L43 43ZM44 44L18 68L21 70L46 46ZM58 30L84 6L87 8L60 33ZM59 35L96 26L96 29L60 38ZM58 40L94 56L92 59L57 43ZM56 44L82 68L79 70L54 46Z"),
        "caracol": Silueta(w: 100, h: 60, vertical: false, d: "M4 58Q2 50 14 48L30 46Q22 30 36 14Q56 0 76 12Q94 26 86 46L96 50Q100 56 92 58ZM10 48L4 34L7 33L13 47ZM16 47L14 32L17 32L19 46Z"),
        "concha": Silueta(w: 100, h: 70, vertical: false, d: "M50 70Q4 66 2 30Q4 2 50 0Q96 2 98 30Q96 66 50 70Z"),
        "cangrejo": Silueta(w: 100, h: 60, vertical: false, d: "M22 30Q24 14 50 12Q76 14 78 30Q76 44 50 46Q24 44 22 30ZM22 22Q8 6 14 2Q24 4 26 18ZM78 22Q92 6 86 2Q76 4 74 18ZM26 38L6 50L8 53L28 42ZM30 42L14 58L17 60L33 45ZM74 38L94 50L92 53L72 42ZM70 42L86 58L83 60L67 45Z"),
        "pulpo": Silueta(w: 80, h: 100, vertical: true, d: "M40 0Q66 2 66 30Q66 46 56 52Q70 70 78 96L72 98Q62 74 50 60Q52 80 48 100L42 100Q42 78 38 60Q30 80 18 98L12 96Q22 74 26 54Q14 48 14 30Q14 2 40 0Z"),
        "estrella": Silueta(w: 100, h: 96, vertical: false, d: "M50.0 2.0L61.2 34.6L95.7 35.2L68.1 55.9L78.2 88.8L50.0 69.0L21.8 88.8L31.9 55.9L4.3 35.2L38.8 34.6Z"),
        "medusa": Silueta(w: 80, h: 100, vertical: true, d: "M0 40Q4 2 40 0Q76 2 80 40Q72 36 64 40Q56 36 48 40Q40 36 32 40Q24 36 16 40Q8 36 0 40ZM14 40Q10 70 16 100L19 100Q14 70 18 40ZM30 40Q28 76 34 100L37 100Q32 76 34 40ZM46 40Q48 76 44 100L47 100Q52 76 50 40ZM62 40Q68 70 62 100L65 100Q72 70 66 40Z"),
        "coral": Silueta(w: 80, h: 90, vertical: true, d: "M36 90L36 60Q20 50 18 30L22 30Q24 46 36 54L36 30Q30 14 34 4L38 4Q36 16 40 28L42 50Q54 40 54 20L58 20Q60 44 44 58L44 90Z"),
        "gusano": Silueta(w: 100, h: 16, vertical: false, d: "M0 8Q10 0 22 6T46 8T70 8T94 8L100 8Q96 14 86 12T62 10T38 10T14 12Q6 14 0 8Z"),
        "ciempies": Silueta(w: 100, h: 30, vertical: false, d: "M0 15Q2 11 8 11L94 12Q100 15 94 18L8 19Q2 19 0 15ZM12 12L8 2L10 2L14 12ZM12 18L8 28L10 28L14 18ZM20 12L16 2L18 2L22 12ZM20 18L16 28L18 28L22 18ZM28 12L24 2L26 2L30 12ZM28 18L24 28L26 28L30 18ZM36 12L32 2L34 2L38 12ZM36 18L32 28L34 28L38 18ZM44 12L40 2L42 2L46 12ZM44 18L40 28L42 28L46 18ZM52 12L48 2L50 2L54 12ZM52 18L48 28L50 28L54 18ZM60 12L56 2L58 2L62 12ZM60 18L56 28L58 28L62 18ZM68 12L64 2L66 2L70 12ZM68 18L64 28L66 28L70 18ZM76 12L72 2L74 2L78 12ZM76 18L72 28L74 28L78 18ZM84 12L80 2L82 2L86 12ZM84 18L80 28L82 28L86 18Z"),
    ]
}
