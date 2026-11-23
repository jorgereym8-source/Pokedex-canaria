import SwiftUI
import SwiftData

struct AjustesView: View {
    @Environment(Ajustes.self) private var ajustes
    @Environment(Almacen.self) private var almacen
    @Environment(Navegacion.self) private var nav
    @Environment(\.modelContext) private var contexto
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @State private var abierto: String?
    @State private var exportar = false
    @State private var confirmarBorrado = false

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    var body: some View {
        @Bindable var aj = ajustes
        ScrollView {
            VStack(alignment: .leading, spacing: tema.hueco) {
                if tema.esPoke { DecoracionPokedex() }
                TituloPantalla(texto: "Ajustes")

                VStack(alignment: .leading, spacing: 8) {
                    Subtitulo("Estilo de la app")
                    HStack(spacing: 10) {
                        ForEach(Estilo.allCases) { e in tarjetaEstilo(e) }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Subtitulo("Personalizar «\(ajustes.d.estilo.nombre)»")
                        Spacer()
                        Button("Restablecer") {
                            withAnimation(tema.animacion) {
                                ajustes.d.restablecer()
                                abierto = nil
                            }
                        }
                        .font(tema.f(0.875, .semi))
                        .foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                    }
                    vistaPrevia
                    VStack(spacing: 0) {
                        ForEach(Paletas.opciones) { o in
                            filaOpcion(o)
                            if o.id != Paletas.opciones.last?.id { Separador() }
                        }
                    }
                    .tarjeta(radio: tema.radio * 0.85)
                    Text("Cada estilo guarda su propia personalización. Toca una fila para abrir su menú.")
                        .font(tema.f(0.8)).foregroundStyle(p.texto2).padding(.horizontal, 4)
                }

                grupo("Diagrama de tamaño") {
                    fila("Tu altura", "Tu silueta en el diagrama; las especies de menos de 30 cm se comparan con una mano") {
                        Paso(valor: $aj.d.altura, minimo: 90, maximo: 230, sufijo: " cm")
                    }
                }

                grupo("Nombres y orden") {
                    selector("Nombres comunes", nil, ["Todos", "Solo el principal"], $aj.d.nombres)
                    Separador()
                    interruptor("Mostrar autoría del nombre científico", nil, $aj.d.autoria)
                    Separador()
                    selector("Orden por defecto", "El número de Pokédex sigue el orden taxonómico", ["Taxonómica", "Nombre común", "Nombre científico"], $aj.d.numeracion)
                }

                VStack(alignment: .leading, spacing: 8) {
                    grupo("Avistamientos") {
                        interruptor("Guardar el lugar", "Coordenadas, altitud, isla y municipio", $aj.d.guardarLugar)
                        Separador()
                        selector("Precisión del lugar", "Aproximada = redondeada a 1 km", ["Exacta", "Aprox. si amenazada", "Siempre aprox."], $aj.d.precision)
                        Separador()
                        interruptor("Guardar el tiempo meteorológico", "Temperatura, cielo, viento, humedad y lluvia (Open-Meteo)", $aj.d.guardarTiempo)
                        Separador()
                        Button { exportar = true } label: {
                            fila("Exportar, copia de seguridad o recuperar", nil) { Icono("flecha", tam: 18).foregroundStyle(tema.texto2) }
                        }
                        .buttonStyle(.plain)
                        Separador()
                        Button { confirmarBorrado = true } label: {
                            fila("Borrar todos los avistamientos", nil, peligro: true) { EmptyView() }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Los avistamientos y tus fotos se guardan solo en este iPhone. Haz copias de seguridad de vez en cuando.")
                        .font(tema.f(0.8)).foregroundStyle(p.texto2).padding(.horizontal, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    grupo("Datos y fotos") {
                        interruptor("Fotos de Biota", "Se cargan desde su web, con crédito; necesitan conexión", $aj.d.fotosBiota)
                        Separador()
                        interruptor("Fotos con licencia libre", "Wikimedia Commons e iNaturalist, con autor y licencia; completan las de Biota", $aj.d.fotosLibres)
                        Separador()
                        Button { Task { await almacen.comprobarDatosNuevos(aMano: true) } } label: {
                            fila("Buscar datos nuevos", almacen.comprobando ? "Comprobando…" : (almacen.mensajeDatos ?? "GitHub publica datos nuevos el día 3 de cada mes")) {
                                if almacen.comprobando { ProgressView() } else { Icono("descargar", tam: 20).foregroundStyle(tema.texto2) }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(almacen.comprobando)
                        if almacen.usandoDescargados {
                            Separador()
                            Button { Task { await almacen.descargarTodas() } } label: {
                                fila("Guardar todas las fichas para usar sin conexión", textoDescarga) {
                                    if almacen.descarga != nil { ProgressView() } else { Icono("descargar", tam: 20).foregroundStyle(tema.texto2) }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(almacen.descarga != nil)
                        }
                        Separador()
                        fila("Datos de especies", textoDatos) { EmptyView() }
                    }
                    Text(almacen.usandoDescargados
                         ? "Usas datos descargados de GitHub, más nuevos que los de la app. Las fichas se guardan al abrirlas."
                         : "Todas las fichas van dentro de la app y funcionan sin conexión. Los datos se actualizan solos el día 3 de cada mes desde Biota y Centinela.")
                        .font(tema.f(0.8)).foregroundStyle(p.texto2).padding(.horizontal, 4)
                }

                grupo("Fuentes y créditos") {
                    let enlaces: [(String, String)] = [
                        ("Banco de Datos de Biodiversidad de Canarias (Biota)", Cat.biota),
                        ("Centinela · especies protegidas", Cat.centinela),
                        ("Normas de uso de Biota", "\(Cat.biota)/normas"),
                        ("REDEXOS · especies exóticas invasoras", Cat.redexos),
                        ("iNaturalist · calendario y fotos con licencia Creative Commons", "https://www.inaturalist.org"),
                        ("Wikimedia Commons · fotos con licencia libre", "https://commons.wikimedia.org"),
                        ("Especies Vegetales en Canarias · Gerardo G. Casanova (enlaces)", "https://endemicascanarias.com"),
                        ("GBIF · categoría UICN (Lista Roja 2022-2)", "https://www.gbif.org/dataset/19491596-35ae-4a91-9a98-85cf505f1bd3"),
                        ("FishBase · tamaño y longevidad de peces", "https://www.fishbase.se"),
                        ("AnAge · longevidad y peso de vertebrados", "https://genomics.senescence.info/species/"),
                        ("Wikidata y Wikipedia · tamaños y formas", "https://www.wikidata.org"),
                        ("Open-Meteo · tiempo de los avistamientos", "https://open-meteo.com"),
                        ("OpenStreetMap · nombres de lugares y contorno de las islas", "https://www.openstreetmap.org/copyright"),
                        ("Tipografías (licencia SIL Open Font)", "https://openfontlicense.org"),
                    ]
                    ForEach(enlaces.indices, id: \.self) { i in
                        if let u = URL(string: enlaces[i].1) {
                            Link(destination: u) {
                                fila(enlaces[i].0, nil) { Icono("externo", tam: 18).foregroundStyle(tema.texto2) }
                            }
                        }
                        if i < enlaces.count - 1 { Separador() }
                    }
                }

                Text("Pokédex Canaria · versión \(version) para iPhone\nUso personal. Las fotos pertenecen a sus autores.")
                    .font(tema.f(0.8)).foregroundStyle(p.texto2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, tema.margen)
            .padding(.top, 12 + 8 * tema.esp)
            .padding(.bottom, 24)
        }
        .pantalla()
        .sheet(isPresented: $exportar) {
            ExportarView()
                .environment(\.tema, tema)
                .environment(\.paleta, tema.fuera)
        }
        .confirmationDialog("¿Borrar todos tus avistamientos? No se puede deshacer.", isPresented: $confirmarBorrado, titleVisibility: .visible) {
            Button("Borrar todos", role: .destructive) {
                try? contexto.delete(model: Avistamiento.self)
                try? contexto.save()
                nav.avisar("Avistamientos borrados")
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var textoDescarga: String {
        if let d = almacen.descarga { return "Guardando… \(miles(d.hechas)) de \(miles(d.total))" }
        return "\(miles(almacen.indice.count)) fichas"
    }

    private var textoDatos: String {
        guard let m = almacen.meta else { return "" }
        return "\(miles(m.taxones ?? almacen.indice.count)) taxones · actualizados el \(m.fecha.map(Fechas.corta) ?? m.actualizado)"
    }

    // MARK: - Piezas

    private func grupo<C: View>(_ titulo: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Subtitulo(titulo)
            VStack(spacing: 0) { contenido() }
                .tarjeta(radio: tema.radio * 0.85)
        }
    }

    private func fila<D: View>(_ t: String, _ sub: String?, peligro: Bool = false, @ViewBuilder _ derecha: () -> D) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(tema.f(0.94, .medio)).foregroundStyle(peligro ? tema.peligro : tema.texto)
                if let sub { Text(sub).font(tema.f(0.75)).foregroundStyle(tema.texto2).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            derecha()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .multilineTextAlignment(.leading)
    }

    private func interruptor(_ t: String, _ sub: String?, _ valor: Binding<Bool>) -> some View {
        fila(t, sub) {
            Toggle(t, isOn: valor).labelsHidden()
        }
    }

    private func selector(_ t: String, _ sub: String?, _ opciones: [String], _ valor: Binding<String>) -> some View {
        fila(t, sub) {
            Menu {
                Picker(t, selection: valor) {
                    ForEach(opciones, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(valor.wrappedValue).font(tema.f(0.94)).foregroundStyle(tema.texto2).multilineTextAlignment(.trailing)
                    Icono("flecha", tam: 14).rotationEffect(.degrees(90)).foregroundStyle(tema.texto2)
                }
            }
        }
    }

    // MARK: Estilos

    private func tarjetaEstilo(_ e: Estilo) -> some View {
        let activo = ajustes.d.estilo == e
        return Button {
            withAnimation(tema.animacion) {
                ajustes.d.estilo = e
                abierto = nil
            }
        } label: {
            VStack(spacing: 8) {
                MiniEstilo(estilo: e).frame(height: 110)
                Text(e.nombre).font(tema.f(0.8, .semi)).foregroundStyle(tema.texto)
            }
            .padding(activo ? 6 : 8)
            .background(tema.esPoke ? tema.fondo : (tema.esCua ? Color.clear : tema.superficie), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(activo ? (tema.esPoke ? tema.texto : tema.acento) : tema.borde, lineWidth: activo ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activo ? .isSelected : [])
    }

    private var vistaPrevia: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: tema.radio * 0.75).fill(tema.esPoke ? tema.carcasa : tema.acento).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Drago").font(tema.esPoke ? tema.f(1.3, .normal, .lcd) : tema.f(1.15, .negrita))
                NombreCientifico(nombre: "Dracaena draco subsp. draco", autor: "(L.) L.", conAutor: ajustes.d.autoria)
                Text("Vista previa").font(tema.f(0.8)).foregroundStyle(tema.texto2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .tarjeta()
    }

    private func filaOpcion(_ o: OpcionEstilo) -> some View {
        let est = ajustes.d.estilo
        let v = ajustes.valor(o.id)
        let esColor = o.id == "color" || o.id == "fondo"
        let estaAbierto = abierto == o.id
        return VStack(spacing: 0) {
            Button {
                withAnimation(tema.animacion) { abierto = estaAbierto ? nil : o.id }
            } label: {
                fila(o.etiqueta(est), nil) {
                    HStack(spacing: 6) {
                        if esColor, let hex = ajustes.d.colorDe(v) { Muestra(hex: hex) }
                        Text(v).font(tema.f(0.94)).foregroundStyle(tema.texto2).lineLimit(1)
                        Icono("flecha", tam: 16).rotationEffect(.degrees(estaAbierto ? 270 : 90)).foregroundStyle(tema.texto2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(estaAbierto ? "Cerrar el menú" : "Abrir el menú")
            if estaAbierto {
                VStack(spacing: 0) {
                    ForEach(o.valores(est), id: \.self) { x in
                        Button {
                            withAnimation(tema.animacion) {
                                ajustes.d.fijar(o.id, x)
                                if x != "Personalizado" { abierto = nil }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if esColor, let hex = ajustes.d.colorDe(x) { Muestra(hex: hex, tam: 18) }
                                Text(x).font(o.id == "letra" ? Fuentes.fuente(x, tam: 16 * (Paletas.escalaLetra[x] ?? 1)) : tema.f(0.94))
                                    .foregroundStyle(tema.texto)
                                Spacer()
                                if x == v { Text("✓").font(tema.f(1, .negrita)).foregroundStyle(tema.esPoke ? tema.texto : tema.acento) }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(x == v ? (tema.esPoke ? tema.superficie2 : tema.superficie) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(x == v ? .isSelected : [])
                    }
                    if o.id == "color" {
                        ColorPicker(selection: Binding(
                            get: { Color(hex: ajustes.d.personalizado[est.rawValue] ?? "#3D6B35") },
                            set: { ajustes.d.fijarPersonalizado($0.hex) }
                        ), supportsOpacity: false) {
                            Text("Elegir color propio").font(tema.f(0.94)).foregroundStyle(tema.texto)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                    }
                }
                .padding(4)
                .background(tema.esPoke ? tema.fondo.opacity(0.7) : tema.fondo, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

/// Círculo con un color
struct Muestra: View {
    let hex: String
    var tam: CGFloat = 16

    var body: some View {
        Circle().fill(Color(hex: hex))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
            .frame(width: tam, height: tam)
    }
}

/// Miniatura de cada estilo para elegirlo
struct MiniEstilo: View {
    let estilo: Estilo

    var body: some View {
        switch estilo {
        case .nat:
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#3D6B35")).frame(height: 8).frame(maxWidth: .infinity, alignment: .leading).scaleEffect(x: 0.6, y: 1, anchor: .leading)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#DCE8D6")).frame(height: 40)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#C9CDC4")).frame(height: 6).scaleEffect(x: 0.8, y: 1, anchor: .leading)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#C9CDC4")).frame(height: 6).scaleEffect(x: 0.55, y: 1, anchor: .leading)
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color(hex: "#F4F5F1"), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "#E1E4DC"), lineWidth: 1))
        case .poke:
            VStack(alignment: .leading, spacing: 6) {
                Circle().fill(Color(hex: "#2F7FD3")).frame(width: 18, height: 18).overlay(Circle().strokeBorder(.white, lineWidth: 2))
                Rectangle().fill(Color(hex: "#C9DDB8")).overlay(Rectangle().strokeBorder(Color(hex: "#2B2B2B"), lineWidth: 2))
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#1F5FA8")).frame(height: 10).scaleEffect(x: 0.6, y: 1, anchor: .leading)
            }
            .padding(8)
            .background(Color(hex: "#C3262F"), in: RoundedRectangle(cornerRadius: 10))
        case .cua:
            HStack(alignment: .bottom, spacing: 8) {
                UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 7)
                    .fill(Color(hex: "#B23A2E")).frame(width: 14, height: 64)
                VStack(spacing: 9) {
                    ForEach(0..<3, id: \.self) { _ in Rectangle().fill(Color(hex: "#2A2620")).frame(height: 1) }
                }
                .padding(.bottom, 6)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background(Color(hex: "#F2EBDC"), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "#2A2620"), lineWidth: 1))
        }
    }
}
