import SwiftUI
import SwiftData
import MapKit

/// Fila de un avistamiento (lista y ficha)
struct FilaAvistamiento: View {
    let a: Avistamiento
    let e: Especie?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        let t = a.tiempo
        let cielo = Meteo.cielo(t?.codigo)
        HStack(spacing: 12) {
            if let e { Miniatura(e: e) }
            VStack(alignment: .leading, spacing: 2) {
                Text(a.comun.isEmpty ? a.nombre : a.comun).font(tema.esPoke ? tema.f(1.3, .normal, .lcd) : tema.f(1, .negrita)).lineLimit(2)
                Text(a.lugarCorto).font(tema.f(0.82)).foregroundStyle(p.texto2).lineLimit(1)
                Text(Fechas.diaHora(a.fecha) + (a.individuos > 1 ? " · \(a.individuos) individuos" : ""))
                    .font(tema.f(0.82)).foregroundStyle(p.texto2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 2) {
                Icono(cielo.1, tam: 22).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                Text(t?.temperatura.map { "\(Int($0.rounded())) °C" } ?? (a.tiempoPendiente ? "…" : ""))
                    .font(tema.f(0.8, .semi))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(t?.codigo != nil ? cielo.0 : "Sin datos del tiempo")
        }
        .padding(.vertical, 10 * tema.esp)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct AvistamientosView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Query(sort: \Avistamiento.fecha, order: .reverse) private var lista: [Avistamiento]
    @State private var modo = "Lista"
    @State private var detalle: Avistamiento?
    @State private var exportar = false

    var body: some View {
        let especies = Set(lista.map(\.codigo))
        let islas = Set(lista.compactMap(\.isla).filter { !$0.hasPrefix("Mar") && !$0.hasPrefix("Fuera") })
        ScrollView {
            VStack(alignment: .leading, spacing: tema.hueco) {
                if tema.esPoke { DecoracionPokedex() }
                HStack(alignment: .top) {
                    TituloPantalla(texto: "Avistamientos")
                    Spacer()
                    BotonIcono(icono: "compartir", etiqueta: "Exportar o importar") { exportar = true }
                }
                Picker("Modo", selection: $modo) {
                    ForEach(["Lista", "Mapa", "Resumen"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack(spacing: 8) {
                    cifra(lista.count, "avistamientos")
                    cifra(especies.count, "especies")
                    cifra(islas.count, "islas")
                }
                if lista.isEmpty {
                    Vacio(icono: "vistas", texto: "Aún no has guardado ningún avistamiento.", detalle: "Abre la ficha de una especie y pulsa «La he visto».")
                } else if modo == "Lista" {
                    listaPorMes
                } else if modo == "Mapa" {
                    MapaAvistamientos(lista: lista.filter(\.tieneLugar))
                        .frame(height: 460)
                        .clipShape(RoundedRectangle(cornerRadius: tema.radio))
                        .overlay(RoundedRectangle(cornerRadius: tema.radio).strokeBorder(tema.borde, lineWidth: 1))
                } else {
                    resumen(especies)
                }
            }
            .padding(.horizontal, tema.margen)
            .padding(.top, 12 + 8 * tema.esp)
            .padding(.bottom, 24)
        }
        .pantalla()
        .sheet(item: $detalle) { a in
            DetalleAvistamientoView(av: a, desdeFicha: false)
                .environment(\.tema, tema)
                .environment(\.paleta, tema.fuera)
        }
        .sheet(isPresented: $exportar) {
            ExportarView()
                .environment(\.tema, tema)
                .environment(\.paleta, tema.fuera)
        }
    }

    private func cifra(_ n: Int, _ t: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(miles(n)).font(tema.esPoke ? tema.f(1.6, .normal, .lcd) : tema.f(1.4, .negrita))
            Text(t).font(tema.f(0.75)).foregroundStyle(tema.texto2)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: 14)
    }

    private var listaPorMes: some View {
        var meses: [(String, [Avistamiento])] = []
        for a in lista {
            let k = Fechas.mesAno(a.fecha)
            if let i = meses.firstIndex(where: { $0.0 == k }) { meses[i].1.append(a) } else { meses.append((k, [a])) }
        }
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(meses.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Subtitulo(meses[i].0)
                    VStack(spacing: 0) {
                        ForEach(meses[i].1) { a in
                            Button { detalle = a } label: { FilaAvistamiento(a: a, e: almacen.especie(a.codigo)) }
                                .buttonStyle(.plain)
                            if a.id != meses[i].1.last?.id { Separador() }
                        }
                    }
                    .tarjeta()
                }
            }
        }
    }

    private func resumen(_ especies: Set<String>) -> some View {
        var vistasPorGrupo: [String: Int] = [:]
        for c in especies { if let e = almacen.especie(c) { vistasPorGrupo[e.grupo, default: 0] += 1 } }
        var porIsla: [String: Int] = [:]
        for a in lista { if let i = a.isla { porIsla[i, default: 0] += 1 } }
        let grupos = Cat.grupos.filter { (almacen.cuentaGrupo[$0] ?? 0) > 0 }
        let islas = porIsla.sorted { $0.value > $1.value }
        return VStack(spacing: tema.hueco) {
            Seccion("Por grupo") {
                ForEach(grupos, id: \.self) { g in
                    let n = almacen.cuentaGrupo[g] ?? 0
                    let v = vistasPorGrupo[g] ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(g)
                            Spacer()
                            Text(atr(v, n))
                        }
                        .font(tema.f(0.8))
                        BarraProgreso(valor: n > 0 ? Double(v) / Double(n) : 0)
                    }
                }
            }
            if !islas.isEmpty {
                Seccion("Por isla") {
                    ForEach(islas.indices, id: \.self) { i in
                        HStack {
                            Text(islas[i].key)
                            Spacer()
                            Text(miles(islas[i].value)).fontWeight(.bold)
                        }
                        .font(tema.f(0.8))
                    }
                }
            }
        }
    }

    private func atr(_ v: Int, _ n: Int) -> AttributedString {
        var a = AttributedString(miles(v))
        a.font = tema.f(0.8, .negrita)
        return a + AttributedString(" de \(miles(n))")
    }
}

/// Mapa con los puntos de los avistamientos
struct MapaAvistamientos: View {
    let lista: [Avistamiento]
    var alTocarIsla: ((String, CLLocationCoordinate2D) -> Void)? = nil
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @State private var posicion: MapCameraPosition = .region(MapaAvistamientos.canarias)
    @State private var elegido: Avistamiento?
    @State private var ajustado = false

    static let canarias = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 28.3, longitude: -15.9),
                                             span: MKCoordinateSpan(latitudeDelta: 2.6, longitudeDelta: 5.6))

    init(lista: [Avistamiento], alTocarIsla: ((String, CLLocationCoordinate2D) -> Void)? = nil) {
        self.lista = lista
        self.alTocarIsla = alTocarIsla
    }

    private struct Punto: Identifiable {
        let id: PersistentIdentifier
        let a: Avistamiento
        let c: CLLocationCoordinate2D
    }

    private var puntos: [Punto] {
        lista.compactMap { a in
            guard let lat = a.lat, let lon = a.lon else { return nil }
            return Punto(id: a.persistentModelID, a: a, c: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $posicion) {
                ForEach(puntos) { pt in
                    Annotation(pt.a.comun, coordinate: pt.c) {
                        Circle()
                            .fill(tema.esPoke ? tema.carcasa : tema.acento)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.25), radius: 2)
                            .padding(8)
                            .contentShape(Circle())
                            .onTapGesture { elegido = pt.a }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { punto in
                elegido = nil
                guard let alTocarIsla, let c = proxy.convert(punto, from: .local) else { return }
                alTocarIsla(Lugar.islaDe(lat: c.latitude, lon: c.longitude), c)
            }
        }
        .overlay(alignment: .bottom) {
            if let a = elegido {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.comun).font(tema.f(0.95, .negrita))
                        Text(Fechas.corta(a.fecha) + " · " + a.lugarCorto).font(tema.f(0.8)).foregroundStyle(tema.texto2).lineLimit(1)
                    }
                    Spacer()
                    Button("Ver ficha") {
                        let c = a.codigo
                        elegido = nil
                        nav.abrir(c)
                    }
                    .font(tema.f(0.875, .semi))
                    .foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
                }
                .padding(12)
                .tarjeta(radio: 14)
                .padding(10)
            }
        }
        .onAppear {
            guard !ajustado else { return }
            ajustado = true
            let pts = puntos.map(\.c)
            guard !pts.isEmpty else { return }
            let lats = pts.map(\.latitude), lons = pts.map(\.longitude)
            let centro = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
            let span = MKCoordinateSpan(latitudeDelta: max(0.03, (lats.max()! - lats.min()!) * 1.4),
                                        longitudeDelta: max(0.03, (lons.max()! - lons.min()!) * 1.4))
            posicion = .region(MKCoordinateRegion(center: centro, span: span))
        }
    }
}

/// Pestaña «Mapa»: tus avistamientos; toca una isla para ver sus especies
struct MapaView: View {
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Query(sort: \Avistamiento.fecha, order: .reverse) private var lista: [Avistamiento]
    @State private var isla: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tema.esPoke { DecoracionPokedex() }
            VStack(alignment: .leading, spacing: 4) {
                TituloPantalla(texto: "Mapa")
                Text("Tus avistamientos. Toca una isla del mapa para ver sus especies.").font(tema.f(0.8)).foregroundStyle(p.texto2)
            }
            MapaAvistamientos(lista: lista.filter(\.tieneLugar)) { nombre, _ in
                isla = Lugar.codigoIsla(nombre) != nil ? nombre : nil
            }
            .clipShape(RoundedRectangle(cornerRadius: tema.radio))
            .overlay(RoundedRectangle(cornerRadius: tema.radio).strokeBorder(tema.esPoke ? tema.oscuroPoke : tema.borde, lineWidth: tema.esPoke ? 3 : 1))
            .overlay(alignment: .top) {
                if let isla, let k = Lugar.codigoIsla(isla) {
                    HStack {
                        Text(isla).font(tema.f(1, .negrita))
                        Spacer()
                        Button("Ver sus especies") {
                            var f = Filtros()
                            f.i = [k]
                            self.isla = nil
                            nav.explorar(f)
                        }
                        .font(tema.f(0.875, .semi))
                        .foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
                        Button { self.isla = nil } label: { Icono("cerrar", tam: 16) }.buttonStyle(.plain)
                    }
                    .padding(12)
                    .tarjeta(radio: 14)
                    .padding(10)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Cat.islasOrden, id: \.self) { k in
                        Chip(texto: Cat.nombreIsla[k] ?? k) {
                            var f = Filtros()
                            f.i = [k]
                            nav.explorar(f)
                        }
                    }
                }
                .padding(.horizontal, tema.margen)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, -tema.margen)
        }
        .padding(.horizontal, tema.margen)
        .padding(.top, 12 + 8 * tema.esp)
        .padding(.bottom, 12)
        .pantalla()
    }
}
