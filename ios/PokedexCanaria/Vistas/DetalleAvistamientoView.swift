import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers
import UIKit

/// Detalle de un avistamiento guardado
struct DetalleAvistamientoView: View {
    let av: Avistamiento
    let desdeFicha: Bool
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @State private var confirmar = false

    init(av: Avistamiento, desdeFicha: Bool = true) {
        self.av = av
        self.desdeFicha = desdeFicha
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cerrar") { cerrar() }
                Spacer()
                Text("Avistamiento").font(tema.f(1.05, .negrita, .titulo))
                Spacer()
                if desdeFicha {
                    Color.clear.frame(width: 50, height: 1)
                } else {
                    Button("Ficha") {
                        let c = av.codigo
                        cerrar()
                        nav.abrir(c)
                    }
                }
            }
            .font(tema.f(1))
            .foregroundStyle(tema.esPoke ? tema.carcasaTxt : tema.acento)
            .padding(.horizontal, tema.margen)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(av.comun).font(tema.esPoke ? tema.f(1.3, .normal, .lcd) : tema.f(1.3, .negrita)).foregroundStyle(p.texto)
                        NombreCientifico(nombre: av.nombre, conAutor: false).foregroundStyle(p.texto)
                    }
                    if let d = av.foto, let img = UIImage(data: d) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: tema.radio))
                            .accessibilityLabel("Tu foto")
                    }
                    datos
                    if let lat = av.lat, let lon = av.lon {
                        let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(initialPosition: .region(MKCoordinateRegion(center: c, latitudinalMeters: 4000, longitudinalMeters: 4000))) {
                            Marker(av.comun, coordinate: c).tint(tema.esPoke ? tema.carcasa : tema.acento)
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: tema.radio))
                        .overlay(RoundedRectangle(cornerRadius: tema.radio).strokeBorder(tema.borde, lineWidth: 1))
                    }
                    Button {
                        confirmar = true
                    } label: {
                        Label("Borrar este avistamiento", systemImage: "trash")
                    }
                    .buttonStyle(EstiloBoton(tipo: .peligro))
                }
                .padding(.horizontal, tema.margen)
                .padding(.bottom, 28)
            }
        }
        .background(FondoApp())
        .presentationDragIndicator(.visible)
        .confirmationDialog("¿Borrar este avistamiento? No se puede deshacer.", isPresented: $confirmar, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                contexto.delete(av)
                try? contexto.save()
                nav.avisar("Avistamiento borrado")
                cerrar()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var datos: some View {
        let t = av.tiempo
        let cielo = Meteo.cielo(t?.codigo)
        var filas: [(String, String, String)] = [
            ("calendario", "Fecha y hora", Fechas.larga(av.fecha)),
            ("pin", "Lugar", av.lugarLargo),
        ]
        if let lat = av.lat, let lon = av.lon {
            let prec = (av.precision ?? 0) > 0 ? " · ±\(Int(av.precision ?? 0)) m" : ""
            filas.append(("mira", "Coordenadas\(av.aproximado ? " (aproximadas)" : "")", String(format: "%.5f, %.5f", lat, lon) + prec))
        }
        if let a = av.altitud { filas.append(("montana", "Altitud", "\(Int(a)) m")) }
        filas.append((cielo.1, "Tiempo", t?.resumen ?? (av.tiempoPendiente ? "Pendiente de completar" : "No guardado")))
        let obs = "\(av.individuos) individuo\(av.individuos > 1 ? "s" : "")" + (av.estados.isEmpty ? "" : " · " + av.estados.joined(separator: ", "))
        filas.append(("vistas", "Observación", obs))
        if !av.notas.isEmpty { filas.append(("hoja", "Notas", av.notas)) }
        return VStack(spacing: 0) {
            ForEach(filas.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Icono(filas[i].0).foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(filas[i].1).font(tema.f(0.75)).foregroundStyle(tema.texto2)
                        Text(filas[i].2).font(tema.f(0.94, filas[i].1 == "Notas" ? .normal : .semi)).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 52)
                if i < filas.count - 1 { Separador() }
            }
        }
        .tarjeta()
    }
}

/// Exportar a CSV, hacer copia de seguridad o recuperarla (compatible con la copia de la versión web)
struct ExportarView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Environment(Almacen.self) private var almacen
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Query(sort: \Avistamiento.fecha, order: .reverse) private var lista: [Avistamiento]
    @State private var csv: URL?
    @State private var copia: URL?
    @State private var importar = false
    @State private var mensaje: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cerrar") { cerrar() }
                Spacer()
                Text("Exportar o importar").font(tema.f(1.05, .negrita, .titulo))
                Spacer()
                Color.clear.frame(width: 50, height: 1)
            }
            .font(tema.f(1))
            .foregroundStyle(tema.esPoke ? tema.carcasaTxt : tema.acento)
            .padding(.horizontal, tema.margen)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 0) {
                        if let csv {
                            ShareLink(item: csv) {
                                fila("Exportar a Excel (CSV)", "Fecha, lugar, coordenadas, tiempo y notas", "descargar")
                            }
                            .buttonStyle(.plain)
                            Separador()
                        }
                        if let copia {
                            ShareLink(item: copia) {
                                fila("Hacer copia de seguridad", "Archivo para recuperar los avistamientos (sin fotos)", "descargar")
                            }
                            .buttonStyle(.plain)
                            Separador()
                        }
                        Button { importar = true } label: {
                            fila("Recuperar una copia", "Elige un archivo de copia de seguridad (también sirve el de la versión web)", "compartir")
                        }
                        .buttonStyle(.plain)
                    }
                    .tarjeta(radio: tema.radio * 0.85)
                    if let mensaje {
                        Text(mensaje).font(tema.f(0.875)).foregroundStyle(p.texto)
                    }
                    Text("Tienes \(lista.count) avistamiento\(lista.count == 1 ? "" : "s") guardado\(lista.count == 1 ? "" : "s") en este iPhone.")
                        .font(tema.f(0.8)).foregroundStyle(p.texto2)
                }
                .padding(.horizontal, tema.margen)
                .padding(.bottom, 28)
            }
        }
        .background(FondoApp())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: lista.count) { @MainActor in prepararArchivos() }
        .fileImporter(isPresented: $importar, allowedContentTypes: [.json, .plainText, .data]) { r in
            switch r {
            case .success(let url): recuperar(url)
            case .failure(let e): mensaje = "No se pudo abrir el archivo: \(e.localizedDescription)"
            }
        }
    }

    private func fila(_ t: String, _ s: String, _ icono: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(tema.f(0.94, .medio)).foregroundStyle(tema.texto)
                Text(s).font(tema.f(0.75)).foregroundStyle(tema.texto2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Icono(icono).foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func prepararArchivos() {
        let hoy = Fechas.isoTexto(Date()).prefix(10)
        let tmp = FileManager.default.temporaryDirectory
        let web = lista.map(\.web)
        let uCsv = tmp.appendingPathComponent("avistamientos-\(hoy).csv")
        let uJson = tmp.appendingPathComponent("avistamientos-copia-\(hoy).json")
        if (try? AvistamientoWeb.csv(web).data(using: .utf8)?.write(to: uCsv, options: .atomic)) != nil { csv = uCsv }
        if let d = try? AvistamientoWeb.copia(web), (try? d.write(to: uJson, options: .atomic)) != nil { copia = uJson }
    }

    private func recuperar(_ url: URL) {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        do {
            let d = try Data(contentsOf: url)
            let entradas = try AvistamientoWeb.leerCopia(d)
            var n = 0
            for w in entradas {
                guard let nuevo = Avistamiento.desde(w, especie: almacen.especie(w.codigo)) else { continue }
                let id = nuevo.uuid
                let previos = (try? contexto.fetch(FetchDescriptor<Avistamiento>(predicate: #Predicate { $0.uuid == id }))) ?? []
                // Como en la web: la copia sustituye al avistamiento con el mismo identificador (se conserva tu foto)
                for x in previos {
                    if nuevo.foto == nil { nuevo.foto = x.foto }
                    contexto.delete(x)
                }
                contexto.insert(nuevo)
                n += 1
            }
            try? contexto.save()
            mensaje = "\(n) avistamiento\(n == 1 ? "" : "s") recuperado\(n == 1 ? "" : "s")"
            nav.avisar(mensaje ?? "")
        } catch {
            mensaje = "No se pudo importar: \(error.localizedDescription)"
        }
    }
}
