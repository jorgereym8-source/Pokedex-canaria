import SwiftUI

/// Contornos de las islas (© OpenStreetMap, generados por scripts/islas_svg.py)
struct DatosMapaIslas: Decodable {
    let ancho: Double
    let alto: Double
    let islas: [String: [String]]
    let km50: Double

    static let compartido: DatosMapaIslas? = {
        guard let u = Bundle.main.url(forResource: "islas", withExtension: "json"),
              let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(DatosMapaIslas.self, from: d)
    }()
}

/// Mapa de las islas coloreado según la presencia de la especie
struct MapaIslas: View {
    let presenciaIslas: String
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    private static let etiquetas: [(String, Double, Double, UnitPoint, String)] = [
        ("H", 35, 147, .bottomLeading, "El Hierro"), ("P", 46, 66, .bottomLeading, "La Palma"), ("G", 77.6, 132, .bottom, "La Gomera"),
        ("T", 127, 71, .bottom, "Tenerife"), ("C", 191.5, 155, .bottom, "Gran Canaria"), ("F", 300, 132, .bottom, "Fuerteventura"),
        ("L", 307, 44, .bottomTrailing, "Lanzarote"),
    ]

    static let colorTraslocada = Color(hex: "#EBC27A")
    static let colorExtinta = Color(hex: "#9AA097")

    var body: some View {
        let datos = DatosMapaIslas.compartido
        let pr = presencia(presenciaIslas)
        let tema = self.tema
        let p = self.p
        Canvas { ctx, size in
            guard let m = datos else { return }
            let k = CGFloat(Double(size.width) / m.ancho)
            ctx.scaleBy(x: k, y: k)
            let sup = tema.c.superficie
            let mar = sup.mezclar(RGB.hex("#3F87B0"), pr["M"] != nil ? 0.3 : 0.1)
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: m.ancho, height: m.alto), cornerRadius: 8), with: .color(mar.color))
            let presente = tema.esPoke ? p.texto : tema.acento
            for (isla, trazos) in m.islas {
                let estado = pr[isla]
                var relleno = tema.superficie, borde = MapaIslas.colorExtinta, discontinuo = false
                switch estado {
                case "s": relleno = presente; borde = tema.esPoke ? p.texto : tema.acentoTinta
                case "d": relleno = tema.acentoSuave; borde = presente; discontinuo = true
                case "t": relleno = MapaIslas.colorTraslocada; borde = Color(hex: "#9A6B12")
                case "x": relleno = MapaIslas.colorExtinta; borde = Color(hex: "#5A6158")
                default: break
                }
                for d in trazos {
                    let ruta = Path(svg: d)
                    ctx.fill(ruta, with: .color(relleno))
                    ctx.stroke(ruta, with: .color(borde), style: StrokeStyle(lineWidth: discontinuo ? 1 : 0.7, lineJoin: .round, dash: discontinuo ? [2, 1.5] : []))
                }
            }
            for (_, x, y, ancla, t) in MapaIslas.etiquetas {
                let r = ctx.resolve(Text(t).font(tema.fPuntos(9, .semi)).foregroundColor(p.texto2))
                ctx.draw(r, at: CGPoint(x: x, y: y + 2), anchor: ancla)
            }
            // escala de 50 km
            let xe = m.ancho - 10 - m.km50, ye = m.alto - 9
            var esc = Path()
            esc.move(to: CGPoint(x: xe, y: ye - 3))
            esc.addLine(to: CGPoint(x: xe, y: ye))
            esc.addLine(to: CGPoint(x: xe + m.km50, y: ye))
            esc.addLine(to: CGPoint(x: xe + m.km50, y: ye - 3))
            ctx.stroke(esc, with: .color(p.texto2), lineWidth: 1)
            let r = ctx.resolve(Text("50 km").font(tema.fPuntos(7.5, .medio)).foregroundColor(p.texto2))
            ctx.draw(r, at: CGPoint(x: xe + m.km50 / 2, y: ye - 4), anchor: .bottom)
        }
        .aspectRatio(CGFloat((datos?.ancho ?? 360) / (datos?.alto ?? 163)), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(descripcion(pr))
    }

    private func descripcion(_ pr: [String: String]) -> String {
        let nombres = ["s": "presente", "d": "dudosa o extinta", "t": "traslocada", "x": "extinta"]
        let partes = Cat.islas.filter { pr[$0.0] != nil }.map { "\($0.1): \(nombres[pr[$0.0]!] ?? pr[$0.0]!)" }
        var t = partes.isEmpty ? "Sin presencia en las islas" : partes.joined(separator: "; ")
        if pr["M"] != nil { t += ". Presente en aguas de Canarias" }
        return t
    }
}
