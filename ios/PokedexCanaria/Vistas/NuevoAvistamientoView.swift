import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import UIKit

/// Hoja para guardar un avistamiento: fecha, lugar (GPS), tiempo del momento, individuos, estado, foto y notas
struct NuevoAvistamientoView: View {
    let e: Especie
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Environment(Ajustes.self) private var ajustes
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    @State private var fecha = Date()
    @State private var lat: Double?
    @State private var lon: Double?
    @State private var precision: Double?
    @State private var altitud: Double?
    @State private var isla: String?
    @State private var municipio: String?
    @State private var paraje: String?
    @State private var lugarTexto = "Buscando…"
    @State private var coordTexto = "—"
    @State private var altTexto = "—"
    @State private var lugarPendiente = false
    @State private var ajustado = false
    @State private var sinPosicion = false
    @State private var tiempo: TiempoAv?
    @State private var tiempoTexto = "Esperando la posición…"
    @State private var individuos = 1
    @State private var estados: [String] = []
    @State private var notas = ""
    @State private var foto: UIImage?
    @State private var verCamara = false
    @State private var itemFoto: PhotosPickerItem?
    @State private var posicion: MapCameraPosition = .region(MapaAvistamientos.canarias)
    @State private var ubicador = Ubicador()
    @State private var guardando = false

    init(especie: Especie) { e = especie }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { cerrar() }
                Spacer()
                Text("Nuevo avistamiento").font(tema.f(1.05, .negrita, .titulo))
                Spacer()
                Button("Guardar") { guardar() }.fontWeight(.bold).disabled(guardando)
            }
            .font(tema.f(1))
            .foregroundStyle(tema.esPoke ? tema.carcasaTxt : tema.acento)
            .padding(.horizontal, tema.margen)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Miniatura(e: e)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(numeroPokedex(e.numero)).font(tema.f(0.75, .semi)).foregroundStyle(tema.texto2)
                            Text(e.nombreComun).font(tema.f(1, .negrita))
                            NombreCientifico(nombre: e.nombre, conAutor: false, em: 0.82).foregroundStyle(tema.texto2)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .tarjeta()

                    if ajustes.d.guardarLugar && !sinPosicion { mapa }

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Icono("calendario").foregroundStyle(colorIcono)
                            DatePicker("Fecha y hora", selection: $fecha)
                                .font(tema.f(0.94, .semi))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 52)
                        if ajustes.d.guardarLugar {
                            Separador()
                            campo("pin", "Lugar", lugarTexto)
                            Separador()
                            campo("mira", "Coordenadas", coordTexto)
                            Separador()
                            campo("montana", "Altitud", altTexto)
                        }
                    }
                    .tarjeta()

                    if ajustes.d.guardarTiempo { seccionTiempo }

                    Seccion("Individuos") {
                        HStack {
                            Text("Cuántos").font(tema.f(0.94))
                            Spacer()
                            Paso(valor: $individuos, minimo: 1, maximo: 9999)
                        }
                        Flujo(espacio: 8) {
                            ForEach(e.esFlora ? Cat.estadosPlanta : Cat.estadosAnimal, id: \.self) { s in
                                Chip(texto: s, activo: estados.contains(s)) {
                                    if let i = estados.firstIndex(of: s) { estados.remove(at: i) } else { estados.append(s) }
                                }
                            }
                        }
                    }

                    fotoPropia

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notas").font(tema.f(1, .negrita)).foregroundStyle(p.texto)
                        TextField("Comportamiento, estado del ejemplar, con quién ibas…", text: $notas, axis: .vertical)
                            .lineLimit(4...10)
                            .font(tema.f(1))
                            .padding(12)
                            .tarjeta(radio: 14)
                    }

                    Button("Guardar avistamiento") { guardar() }
                        .buttonStyle(EstiloBoton())
                        .disabled(guardando)
                }
                .padding(.horizontal, tema.margen)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FondoApp())
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(guardando)
        .task { @MainActor in await ubicar() }
        .onChange(of: itemFoto) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let i = UIImage(data: d) { foto = i }
            }
        }
        .fullScreenCover(isPresented: $verCamara) {
            Camara { img in
                if let img { foto = img }
                verCamara = false
            }
            .ignoresSafeArea()
        }
    }

    private var colorIcono: Color { tema.esPoke ? tema.texto : tema.acento }

    private func campo(_ icono: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 12) {
            Icono(icono).foregroundStyle(colorIcono)
            VStack(alignment: .leading, spacing: 2) {
                Text(k).font(tema.f(0.75)).foregroundStyle(tema.texto2)
                Text(v).font(tema.f(0.94, .semi)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("auto").font(tema.f(0.7, .semi)).foregroundStyle(tema.esPoke ? tema.texto : tema.acentoTinta)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(tema.acentoSuave, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 52)
    }

    private struct PuntoUnico: Identifiable {
        let id = 0
        let c: CLLocationCoordinate2D
    }

    private var puntoActual: [PuntoUnico] {
        guard let lat, let lon else { return [] }
        return [PuntoUnico(c: CLLocationCoordinate2D(latitude: lat, longitude: lon))]
    }

    private var mapa: some View {
        VStack(alignment: .leading, spacing: 6) {
            MapReader { proxy in
                Map(position: $posicion) {
                    ForEach(puntoActual) { pt in
                        MapCircle(center: pt.c, radius: max(10, precision ?? 10))
                            .foregroundStyle(tema.acento.opacity(0.12))
                            .stroke(tema.acento, lineWidth: 1)
                        Marker(e.nombreComun, coordinate: pt.c)
                            .tint(tema.esPoke ? tema.carcasa : tema.acento)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .onTapGesture { punto in
                    guard let c = proxy.convert(punto, from: .local) else { return }
                    moverA(c)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: tema.radio))
            .overlay(RoundedRectangle(cornerRadius: tema.radio).strokeBorder(tema.borde, lineWidth: 1))
            .overlay {
                if lat == nil {
                    Text("Buscando tu posición…").font(tema.f(0.8)).padding(10).background(.thinMaterial, in: Capsule())
                }
            }
            Text("Toca el mapa para mover el punto si hace falta.").font(tema.f(0.75)).foregroundStyle(p.texto2)
        }
    }

    private var seccionTiempo: some View {
        Seccion("Tiempo en ese momento") {
            if let t = tiempo, let temp = t.temperatura {
                let cielo = Meteo.cielo(t.codigo)
                HStack(spacing: 12) {
                    Icono(cielo.1, tam: 44).foregroundStyle(colorIcono)
                    Text("\(Int(temp.rounded())) °C").font(tema.f(2, .negrita))
                    Text(cielo.0).foregroundStyle(tema.texto2)
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        datoTiempo("Viento", "\(Int((t.viento ?? 0).rounded())) km/h · \(Meteo.rumbo(t.direccion))")
                        datoTiempo("Humedad", "\(decimal(t.humedad ?? 0, 0)) %")
                    }
                    GridRow {
                        datoTiempo("Lluvia", "\(decimal(t.lluvia ?? 0, 1)) mm")
                        datoTiempo("Nubosidad", "\(decimal(t.nubosidad ?? 0, 0)) %")
                    }
                }
                FuenteDato("Fuente: Open-Meteo")
            } else {
                Text(tiempoTexto).foregroundStyle(tema.texto2).font(tema.f(0.92))
            }
        }
    }

    private func datoTiempo(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(tema.f(0.75)).foregroundStyle(tema.texto2)
            Text(v).font(tema.f(0.94, .semi))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.superficie2, in: RoundedRectangle(cornerRadius: 10))
    }

    private var fotoPropia: some View {
        VStack(spacing: 10) {
            if let foto {
                Image(uiImage: foto)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { verCamara = true } label: {
                        Label("Hacer foto", systemImage: "camera")
                    }
                    .buttonStyle(EstiloBoton(tipo: .secundario))
                }
                PhotosPicker(selection: $itemFoto, matching: .images) {
                    Label(foto == nil ? "Elegir foto" : "Cambiar foto", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .font(tema.f(1, .negrita))
                        .foregroundStyle(p.texto)
                        .background(tema.esCua ? Color.clear : tema.superficie2, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : tema.radio * 0.75))
                        .overlay(RoundedRectangle(cornerRadius: tema.esCua ? 0 : tema.radio * 0.75).strokeBorder(tema.esCua ? p.texto : .clear, lineWidth: 1))
                }
            }
            Text("Tu foto se guarda solo en este iPhone").font(tema.f(0.75)).foregroundStyle(p.texto2)
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tema.borde, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }

    // MARK: - Lugar y tiempo

    @MainActor
    private func ubicar() async {
        guard ajustes.d.guardarLugar else { return }
        do {
            let l = try await ubicador.ubicar()
            lat = l.coordinate.latitude
            lon = l.coordinate.longitude
            precision = l.horizontalAccuracy >= 0 ? l.horizontalAccuracy.rounded() : nil
            if l.verticalAccuracy >= 0 {
                altitud = l.altitude.rounded()
                altTexto = "\(Int(l.altitude.rounded())) m (GPS)"
            } else {
                altTexto = "…"
            }
            isla = Lugar.islaDe(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
            lugarTexto = isla ?? "—"
            coordTexto = String(format: "%.5f, %.5f", l.coordinate.latitude, l.coordinate.longitude) + " · ±\(Int(precision ?? 0)) m"
            posicion = .region(MKCoordinateRegion(center: l.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
            await completarLugar()
            if ajustes.d.guardarTiempo {
                if let t = try? await Servicios.tiempoAhora(lat: l.coordinate.latitude, lon: l.coordinate.longitude) {
                    tiempo = t
                } else {
                    tiempoTexto = "Sin conexión: el tiempo de este momento se completará solo más tarde."
                }
            }
        } catch {
            sinPosicion = true
            lugarTexto = error.localizedDescription
            tiempoTexto = "Sin posición no se puede consultar el tiempo."
        }
    }

    @MainActor
    private func completarLugar() async {
        guard let lat, let lon else { return }
        if let l = try? await Servicios.nombreLugar(lat: lat, lon: lon) {
            municipio = l.municipio
            paraje = l.paraje
            lugarPendiente = false
            lugarTexto = [l.paraje, l.municipio, isla ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        } else {
            lugarPendiente = true
            lugarTexto = "\(isla ?? "") (el nombre del lugar se completará con conexión)"
        }
        if altitud == nil || ajustado {
            if let a = try? await Servicios.altitud(lat: lat, lon: lon) {
                altitud = a
                altTexto = "\(Int(a)) m (modelo del terreno)"
            } else if altitud == nil {
                altTexto = "—"
            }
        }
    }

    private func moverA(_ c: CLLocationCoordinate2D) {
        lat = c.latitude
        lon = c.longitude
        precision = 0
        ajustado = true
        isla = Lugar.islaDe(lat: c.latitude, lon: c.longitude)
        coordTexto = String(format: "%.5f, %.5f", c.latitude, c.longitude) + " · ajustado a mano"
        Task { await completarLugar() }
    }

    // MARK: - Guardar

    private func guardar() {
        guardando = true
        let a = Avistamiento(codigo: e.codigo, nombre: e.nombre, comun: e.nombreComun, fecha: fecha)
        a.individuos = individuos
        a.estados = estados
        a.notas = notas.trimmingCharacters(in: .whitespacesAndNewlines)
        a.lat = lat
        a.lon = lon
        a.precision = precision
        a.altitud = altitud
        a.isla = isla
        a.municipio = municipio
        a.paraje = paraje
        a.ajustadoAMano = ajustado
        a.lugarPendiente = lugarPendiente && lat != nil
        a.tiempo = tiempo
        let modo = ajustes.d.precision
        if let la = lat, let lo = lon, modo == "Siempre aprox." || (modo == "Aprox. si amenazada" && e.esAmenazada) {
            a.lat = (la * 100).rounded() / 100
            a.lon = (lo * 100).rounded() / 100
            a.precision = 1000
            a.aproximado = true
        }
        // Si la fecha no es la de ahora, el tiempo se busca en el histórico
        if tiempo != nil && abs(fecha.timeIntervalSinceNow) > 3 * 3600 {
            a.tiempo = nil
        }
        if ajustes.d.guardarTiempo && a.tiempo == nil && a.lat != nil { a.tiempoPendiente = true }
        if let foto { a.foto = Fotos.reducir(foto) }
        contexto.insert(a)
        try? contexto.save()
        nav.avisar("Avistamiento de \(e.nombreComun) guardado")
        cerrar()
    }
}

/// Selector − n +
struct Paso: View {
    @Binding var valor: Int
    var minimo: Int
    var maximo: Int
    var sufijo: String = ""
    @Environment(\.tema) private var tema

    var body: some View {
        HStack(spacing: 4) {
            boton("−", -1)
            Text("\(valor)\(sufijo)").font(tema.f(1, .negrita)).frame(minWidth: 64)
                .accessibilityValue("\(valor)\(sufijo)")
            boton("+", 1)
        }
    }

    private func boton(_ t: String, _ d: Int) -> some View {
        Button {
            valor = min(maximo, max(minimo, valor + d))
        } label: {
            Text(t).font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(tema.superficie2, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(d > 0 ? "Uno más" : "Uno menos")
    }
}
