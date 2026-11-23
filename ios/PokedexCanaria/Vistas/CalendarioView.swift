import SwiftUI

/// Calendario de observaciones en Canarias (iNaturalist): floración y frutos en plantas, observaciones en animales
struct CalendarioView: View {
    let e: Especie
    @State private var datos: Servicios.Fenologia?
    @State private var fallo = false
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    init(e: Especie) { self.e = e }

    var body: some View {
        Seccion("Calendario") {
            if let d = datos {
                if d.n == 0 {
                    Text("Todavía no hay observaciones de este taxón en Canarias en iNaturalist.").font(tema.f(0.92)).foregroundStyle(p.texto2)
                } else {
                    rejilla(d)
                }
            } else if fallo {
                Text("No se ha podido consultar iNaturalist (¿sin conexión?).").font(tema.f(0.92)).foregroundStyle(p.texto2)
            } else {
                Text("Consultando observaciones…").font(tema.f(0.8)).foregroundStyle(p.texto2).padding(.vertical, 8)
            }
        }
        .task(id: e.codigo) { @MainActor in
            do {
                datos = try await Servicios.fenologia(nombre: e.nombre, codigo: e.codigo, flora: e.esFlora)
            } catch {
                fallo = true
            }
        }
    }

    private func rejilla(_ d: Servicios.Fenologia) -> some View {
        let mes = Calendar.current.component(.month, from: Date()) - 1
        let porFlor = e.esFlora && (d.flor.contains { $0 > 0 } || d.fruto.contains { $0 > 0 })
        let filas: [(String, String, [Int])] = porFlor ? [("flor", "Floración", d.flor), ("fruto", "Frutos", d.fruto)] : [("", "Observaciones", d.total)]
        let maximo = max(1, filas.flatMap { $0.2 }.max() ?? 1)
        let colorPrincipal = tema.esPoke ? p.texto : tema.acento
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text(Cat.meses[i])
                            .font(tema.f(0.75, i == mes ? .extra : .medio))
                            .overlay(alignment: .bottom) {
                                if i == mes { Rectangle().fill(p.texto).frame(height: 2).offset(y: 2) }
                            }
                        ForEach(filas.indices, id: \.self) { k in
                            let v = filas[k].2[i]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tema.superficie2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(filas[k].0 == "fruto" ? MapaIslas.colorTraslocada : colorPrincipal)
                                        .opacity(v > 0 ? 0.25 + 0.75 * Double(v) / Double(maximo) : 0)
                                )
                                .frame(height: 18)
                                .accessibilityLabel("\(Cat.mesesLargos[i]): \(v) observaciones")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Flujo(espacio: 14, espacioLinea: 6) {
                ForEach(filas.indices, id: \.self) { k in
                    Leyenda(texto: filas[k].1, relleno: filas[k].0 == "fruto" ? MapaIslas.colorTraslocada : colorPrincipal)
                }
                Text("Más intenso = más observaciones · \(Cat.mesesLargos[mes]) subrayado").font(tema.f(0.75)).foregroundStyle(p.texto2)
            }
            FuenteDato("Fuente: iNaturalist, \(miles(d.n)) observaciones verificables en Canarias\(d.especie ? " (a nivel de especie)" : "").")
        }
    }
}
