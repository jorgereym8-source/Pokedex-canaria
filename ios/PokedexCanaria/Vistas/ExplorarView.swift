import SwiftUI
import SwiftData

struct ExplorarView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(Ajustes.self) private var ajustes
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Query private var avistamientos: [Avistamiento]
    @State private var resultados: [Especie] = []
    @State private var calculado = false
    @State private var verFiltros = false

    private struct Clave: Equatable {
        let q: String
        let f: Filtros
        let orden: Orden
        let vistas: Set<String>
        let n: Int
    }

    var body: some View {
        let vistas = Set(avistamientos.map(\.codigo))
        let orden = nav.orden ?? ajustes.ordenPorDefecto
        let clave = Clave(q: nav.q, f: nav.filtros, orden: orden, vistas: nav.filtros.novistas ? vistas : [], n: almacen.indice.count)
        ScrollViewReader { lector in
            ScrollView {
                VStack(alignment: .leading, spacing: tema.hueco) {
                    if tema.esPoke { DecoracionPokedex() }
                    HStack(alignment: .lastTextBaseline) {
                        TituloPantalla(texto: "Explorar")
                        Spacer()
                        if calculado {
                            Text("\(miles(resultados.count)) \(resultados.count == 1 ? "especie" : "especies")")
                                .font(tema.f(0.8)).foregroundStyle(p.texto2)
                        }
                    }
                    .id("arriba")
                    buscador
                    chips
                    Menu {
                        Picker("Orden", selection: Binding(get: { orden }, set: { nav.orden = $0 })) {
                            ForEach(Orden.allCases) { o in Text(o.titulo).tag(o) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Orden:").foregroundStyle(p.texto2)
                            Text(orden.titulo).fontWeight(.semibold).foregroundStyle(p.texto)
                            Icono("flecha", tam: 14).rotationEffect(.degrees(90)).foregroundStyle(p.texto2)
                        }
                        .font(tema.f(0.8))
                    }
                    lista(vistas)
                }
                .padding(.horizontal, tema.margen)
                .padding(.top, 12 + 8 * tema.esp)
                .padding(.bottom, 24)
            }
            .onChange(of: nav.versionExplorar) { _, _ in
                lector.scrollTo("arriba", anchor: .top)
            }
        }
        .pantalla()
        .task(id: clave) { @MainActor in
            if calculado { try? await Task.sleep(nanoseconds: 160_000_000) }
            if Task.isCancelled { return }
            resultados = Indice.filtrar(almacen.indice, q: clave.q, f: clave.f, vistas: vistas, orden: clave.orden)
            calculado = true
        }
        .sheet(isPresented: $verFiltros) {
            FiltrosView(vistas: vistas)
                .environment(\.tema, tema)
                .environment(\.paleta, tema.fuera)
        }
    }

    private var buscador: some View {
        @Bindable var nav = nav
        return HStack(spacing: 10) {
            Icono("buscar", tam: 20)
            TextField("Nombre científico, común, familia o código", text: $nav.q)
                .font(tema.esCua ? tema.f(1.4, .medio, .mano) : .system(size: 16))
                .foregroundStyle(tema.esCua ? tema.acento : tema.texto)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !nav.q.isEmpty {
                Button { nav.q = "" } label: { Icono("cerrar", tam: 18) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar búsqueda")
            }
        }
        .foregroundStyle(tema.esPoke ? tema.texto2 : p.texto2)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .modifier(EstiloBuscador())
    }

    private var chips: some View {
        let f = nav.filtros
        var activos: [(String, String, String)] = []   // (clave, valor, texto)
        for v in f.g { activos.append(("g", v, v)) }
        for v in f.i { activos.append(("i", v, Cat.nombreIsla[v] ?? v)) }
        for v in f.nv { activos.append(("nv", v, Cat.nombreNivel[v] ?? v)) }
        for v in f.cc { activos.append(("cc", v, "C. Canario: \(v)")) }
        for v in f.ce { activos.append(("ce", v, "C. Español: \(v)")) }
        for v in f.md { activos.append(("md", v, v)) }
        for v in f.hb { activos.append(("hb", v, v)) }
        for v in f.ui { activos.append(("ui", v, "UICN: \(Cat.categoriaUICN(v)?.nombre ?? v)")) }
        if f.inv { activos.append(("inv", "", "Invasoras")) }
        if f.am { activos.append(("am", "", "Amenazadas")) }
        if f.pr { activos.append(("pr", "", "Protegidas")) }
        if f.foto { activos.append(("foto", "", "Con foto")) }
        if f.son { activos.append(("son", "", "Con sonido")) }
        if f.novistas { activos.append(("novistas", "", "No vistas")) }
        if f.ext { activos.append(("ext", "", "Sin extinguidas")) }
        let n = f.cuantos
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(texto: n > 0 ? "Filtros · \(n)" : "Filtros", oscuro: true, icono: "filtro") { verFiltros = true }
                ForEach(activos.indices, id: \.self) { i in
                    let a = activos[i]
                    Chip(texto: a.2, activo: true, quitar: true) { quitar(a.0, a.1) }
                        .accessibilityLabel("Quitar filtro \(a.2)")
                }
            }
            .padding(.horizontal, tema.margen)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, -tema.margen)
    }

    private func quitar(_ k: String, _ v: String) {
        var f = nav.filtros
        switch k {
        case "g": f.g.removeAll { $0 == v }
        case "i": f.i.removeAll { $0 == v }
        case "nv": f.nv.removeAll { $0 == v }
        case "cc": f.cc.removeAll { $0 == v }
        case "ce": f.ce.removeAll { $0 == v }
        case "md": f.md.removeAll { $0 == v }
        case "hb": f.hb.removeAll { $0 == v }
        case "ui": f.ui.removeAll { $0 == v }
        case "inv": f.inv = false
        case "am": f.am = false
        case "pr": f.pr = false
        case "foto": f.foto = false
        case "son": f.son = false
        case "novistas": f.novistas = false
        case "ext": f.ext = false
        default: break
        }
        nav.filtros = f
    }

    @ViewBuilder
    private func lista(_ vistas: Set<String>) -> some View {
        if !calculado {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        } else if resultados.isEmpty {
            Vacio(icono: "buscar", texto: "No hay especies con esa búsqueda o esos filtros.")
        } else {
            let isla = nav.filtros.islaUnica
            LazyVStack(spacing: 0) {
                ForEach(resultados) { e in
                    NavigationLink(value: Ruta.especie(e.codigo)) {
                        FilaEspecie(e: e, numero: numero(e, isla), vista: vistas.contains(e.codigo))
                    }
                    .buttonStyle(.plain)
                    if e.codigo != resultados.last?.codigo { Separador() }
                }
            }
            .tarjeta(ligera: true)
        }
    }

    private func numero(_ e: Especie, _ isla: String?) -> String {
        if let k = isla, let n = e.regional[k] { return "\(Cat.sigla[k] ?? k) \(String(format: "%04d", n))" }
        return numeroPokedex(e.numero)
    }
}

/// Hoja de filtros
struct FiltrosView: View {
    let vistas: Set<String>
    @Environment(Almacen.self) private var almacen
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.dismiss) private var cerrar
    @State private var borrador = Filtros()
    @State private var listo = false

    var body: some View {
        let n = Indice.contar(almacen.indice, q: nav.q, f: borrador, vistas: vistas)
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { cerrar() }
                Spacer()
                Text("Filtros").font(tema.f(1.05, .negrita, .titulo))
                Spacer()
                Button("Limpiar") { withAnimation(tema.animacion) { borrador = Filtros() } }
            }
            .font(tema.f(1))
            .foregroundStyle(tema.esPoke ? tema.carcasaTxt : tema.acento)
            .padding(.horizontal, tema.margen)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    grupo("Grupo", "g", Cat.grupos.map { ($0, $0) })
                    grupo("Isla", "i", Cat.islas.reversed().map { ($0.0, $0.1) })
                    grupo("Endemicidad y origen", "nv", Cat.niveles)
                    grupo("Categoría UICN (mundial)", "ui", Cat.uicn.filter { !["EX", "EW"].contains($0.codigo) }.map { ($0.codigo, "\($0.nombre) (\($0.codigo))") })
                    grupo("Catálogo Canario de Especies Protegidas", "cc", Cat.catalogoCanario.map { ($0, $0) })
                    grupo("Catálogo Español", "ce", Cat.catalogoEspanol.map { ($0, $0) })
                    grupo("Medio", "md", [("Terrestre", "Terrestre"), ("Marino", "Marino")])
                    grupo("Hábitat (los más frecuentes)", "hb", almacen.habitats.map { ($0, $0) })
                    VStack(spacing: 0) {
                        interruptor("Solo exóticas invasoras", \.inv)
                        Separador()
                        interruptor("Solo amenazadas", \.am)
                        Separador()
                        interruptor("Solo protegidas (con ficha en Centinela)", \.pr)
                        Separador()
                        interruptor("Solo con fotografía", \.foto)
                        Separador()
                        interruptor("Solo con canto o sonido", \.son)
                        Separador()
                        interruptor("Ocultar las que ya he visto", \.novistas)
                        Separador()
                        interruptor("Ocultar extinguidas", \.ext)
                    }
                    .tarjeta(radio: tema.radio * 0.85)
                    Button("Ver \(miles(n)) \(n == 1 ? "especie" : "especies")") {
                        nav.filtros = borrador
                        cerrar()
                    }
                    .buttonStyle(EstiloBoton())
                }
                .padding(.horizontal, tema.margen)
                .padding(.bottom, 28)
            }
        }
        .background(FondoApp())
        .presentationDragIndicator(.visible)
        .onAppear {
            if !listo {
                borrador = nav.filtros
                listo = true
            }
        }
    }

    private func lista(_ k: String) -> [String] {
        switch k {
        case "g": return borrador.g
        case "i": return borrador.i
        case "nv": return borrador.nv
        case "ui": return borrador.ui
        case "cc": return borrador.cc
        case "ce": return borrador.ce
        case "md": return borrador.md
        default: return borrador.hb
        }
    }

    private func alternar(_ k: String, _ v: String) {
        var l = lista(k)
        if let i = l.firstIndex(of: v) { l.remove(at: i) } else { l.append(v) }
        switch k {
        case "g": borrador.g = l
        case "i": borrador.i = l
        case "nv": borrador.nv = l
        case "ui": borrador.ui = l
        case "cc": borrador.cc = l
        case "ce": borrador.ce = l
        case "md": borrador.md = l
        default: borrador.hb = l
        }
    }

    private func grupo(_ titulo: String, _ k: String, _ valores: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Subtitulo(titulo)
            Flujo(espacio: 8) {
                ForEach(valores.indices, id: \.self) { i in
                    let v = valores[i]
                    Chip(texto: v.1, activo: lista(k).contains(v.0)) { alternar(k, v.0) }
                }
            }
        }
    }

    private func interruptor(_ t: String, _ ruta: WritableKeyPath<Filtros, Bool>) -> some View {
        Toggle(isOn: Binding(get: { borrador[keyPath: ruta] }, set: { borrador[keyPath: ruta] = $0 })) {
            Text(t).font(tema.f(0.94, .medio))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
    }
}
