import SwiftUI
import SwiftData

/// Raíz de la app: aplica el estilo, carga los datos y muestra las pestañas
struct RaizView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(Ajustes.self) private var ajustes
    @Environment(Navegacion.self) private var nav
    @Environment(\.colorScheme) private var esquema
    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var fase
    @State private var hora = Calendar.current.component(.hour, from: Date())

    private let reloj = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    var body: some View {
        let calc = TemaCalculo.calcular(ajustes.d, sistemaOscuro: esquema == .dark, hora: hora)
        let tema = Tema(calc)
        ZStack {
            FondoApp()
            switch almacen.estado {
            case .cargando:
                VStack(spacing: 14) {
                    Image("Logo").resizable().frame(width: 72, height: 72)
                    Text("Cargando especies…").font(tema.f(1)).foregroundStyle(tema.fuera.texto2)
                    ProgressView().tint(tema.fuera.texto2)
                }
            case .error(let m):
                Vacio(icono: "alerta", texto: "No se han podido cargar los datos de especies.", detalle: m)
            case .listo:
                Pestanas()
            }
        }
        .overlay(alignment: .bottom) {
            if let a = nav.aviso {
                Text(a)
                    .font(tema.f(0.875))
                    .foregroundStyle(tema.esPoke ? Color.white : tema.fondo)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(tema.esPoke ? tema.oscuroPoke : tema.texto, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { nav.aviso = nil }
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(tema.animacion, value: nav.aviso)
        .environment(\.tema, tema)
        .environment(\.paleta, tema.fuera)
        .foregroundStyle(tema.fuera.texto)
        .tint(tema.esPoke ? tema.carcasaTxt : tema.acento)
        .preferredColorScheme(ajustes.valor("tema") == "Automático" ? nil : (calc.oscuro ? .dark : .light))
        .task { @MainActor in
            await almacen.cargar()
            await completarPendientes()
            await almacen.comprobarDatosNuevos()
        }
        .onChange(of: fase) { _, f in
            guard f == .active else { return }
            hora = Calendar.current.component(.hour, from: Date())
            Task {
                await completarPendientes()
                await almacen.comprobarDatosNuevos()
            }
        }
        .onChange(of: almacen.mensajeDatos) { _, m in
            if let m, m.hasPrefix("Datos actualizados") { nav.avisar(m) }
        }
        .onReceive(reloj) { _ in hora = Calendar.current.component(.hour, from: Date()) }
    }

    @MainActor
    private func completarPendientes() async {
        let n = await Pendientes.completar(contexto)
        if n > 0 { nav.avisar("Se ha completado el tiempo de avistamientos guardados sin conexión") }
    }
}

/// Las cinco pestañas; cada una conserva su navegación
struct Pestanas: View {
    @Environment(Navegacion.self) private var nav

    var body: some View {
        ZStack {
            ForEach(Navegacion.Pestana.allCases) { p in
                if nav.visitadas.contains(p) {
                    pila(p)
                        .opacity(nav.pestana == p ? 1 : 0)
                        .allowsHitTesting(nav.pestana == p)
                        .accessibilityHidden(nav.pestana != p)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { BarraPestanas() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func pila(_ p: Navegacion.Pestana) -> some View {
        let b = Bindable(nav)
        switch p {
        case .inicio: NavigationStack(path: b.rutaInicio) { InicioView().destinos() }
        case .explorar: NavigationStack(path: b.rutaExplorar) { ExplorarView().destinos() }
        case .mapa: NavigationStack(path: b.rutaMapa) { MapaView().destinos() }
        case .vistas: NavigationStack(path: b.rutaVistas) { AvistamientosView().destinos() }
        case .ajustes: NavigationStack(path: b.rutaAjustes) { AjustesView().destinos() }
        }
    }
}

extension View {
    func destinos() -> some View {
        navigationDestination(for: Ruta.self) { r in
            switch r {
            case .especie(let c): FichaView(codigo: c)
            }
        }
    }
}

/// Barra de pestañas con el aspecto de cada estilo
struct BarraPestanas: View {
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Navegacion.Pestana.allCases) { p in
                let activa = nav.pestana == p
                Button {
                    withAnimation(tema.animacion) { nav.ir(p) }
                } label: {
                    VStack(spacing: tema.esPoke ? 6 : 3) {
                        if !tema.esCua { Icono(p.icono, tam: 24) }
                        etiqueta(p.titulo, activa: activa)
                    }
                    .frame(maxWidth: .infinity, minHeight: tema.esCua ? 44 : 48)
                    .foregroundStyle(color(activa))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(p.titulo)
                .accessibilityAddTraits(activa ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(alignment: .top) {
            fondo.ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            if !tema.esPoke {
                Rectangle().fill(tema.esCua ? tema.texto : tema.borde).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private func etiqueta(_ t: String, activa: Bool) -> some View {
        switch tema.estilo {
        case .poke:
            Text(t.uppercased()).font(Fuentes.fuente("Press Start 2P", tam: 7)).lineLimit(1)
        case .cua:
            Text(t.lowercased()).font(tema.f(1, .normal, .titulo)).underline(activa)
        case .nat:
            Text(t).font(tema.f(0.65, .semi)).lineLimit(1)
        }
    }

    private func color(_ activa: Bool) -> Color {
        switch tema.estilo {
        case .poke: return activa ? Color(hex: "#FFD23F") : Color(hex: "#BFBFBF")
        case .cua: return activa ? tema.texto : tema.texto2
        case .nat: return activa ? tema.acento : tema.texto2
        }
    }

    @ViewBuilder
    private var fondo: some View {
        if tema.esPoke {
            tema.oscuroPoke
        } else if tema.esCua || !tema.c.translucido {
            tema.fondo
        } else {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                tema.c.barraFondo.color.opacity(0.85)
            }
        }
    }
}
