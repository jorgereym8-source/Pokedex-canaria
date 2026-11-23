import SwiftUI

// MARK: - Tarjetas

/// Caja con el aspecto de cada estilo (tarjetas, secciones y listas de la web)
struct ModTarjeta: ViewModifier {
    var radio: CGFloat?
    var relleno: Color?
    /// Para listas muy largas: sin sombra (la sombra obliga a dibujar la lista entera)
    var ligera = false
    @Environment(\.tema) private var tema

    func body(content: Content) -> some View {
        let r: CGFloat = tema.esPoke ? 6 : (tema.esCua ? 0 : (radio ?? tema.radio))
        let forma = RoundedRectangle(cornerRadius: r, style: .continuous)
        let fondo = relleno ?? (tema.esCua ? Color.clear : (tema.esPoke ? tema.fondo : tema.superficie))
        let borde = tema.esPoke ? tema.oscuroPoke : (tema.esCua ? tema.texto : tema.borde)
        return Group {
            if ligera {
                // Sin recorte ni sombra: así una lista de miles de filas sigue siendo ligera
                content
                    .background(forma.fill(fondo))
                    .overlay(forma.strokeBorder(borde, lineWidth: tema.esPoke ? 3 : 1))
            } else {
                content
                    .background(fondo)
                    .clipShape(forma)
                    .overlay(forma.strokeBorder(borde, lineWidth: tema.esPoke ? 3 : 1))
                    .modifier(Sombra(activa: tema.esPoke))
            }
        }
        .environment(\.paleta, tema.dentro)
        .foregroundStyle(tema.texto)
        .tint(tema.acento)
    }

    private struct Sombra: ViewModifier {
        let activa: Bool
        func body(content: Content) -> some View {
            Group {
                if activa {
                    content.compositingGroup().shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 3)
                } else {
                    content
                }
            }
        }
    }
}

extension View {
    func tarjeta(radio: CGFloat? = nil, relleno: Color? = nil, ligera: Bool = false) -> some View {
        modifier(ModTarjeta(radio: radio, relleno: relleno, ligera: ligera))
    }

    /// Pantalla con el fondo de la app y sin barra de navegación del sistema
    func pantalla() -> some View {
        modifier(ModPantalla())
    }
}

struct ModPantalla: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FondoApp())
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
    }
}

/// Sección con título dentro de una tarjeta
struct Seccion<Contenido: View>: View {
    var titulo: String?
    var enlace: String?
    var accion: (() -> Void)?
    @ViewBuilder var contenido: Contenido
    @Environment(\.tema) private var tema

    init(_ titulo: String? = nil, enlace: String? = nil, accion: (() -> Void)? = nil, @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.enlace = enlace
        self.accion = accion
        self.contenido = contenido()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let titulo {
                TituloSeccion(titulo, enlace: enlace, accion: accion)
            }
            contenido
        }
        .padding(16 * tema.esp)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }
}

// MARK: - Títulos

/// Título grande de pantalla (h1)
struct TituloPantalla: View {
    let texto: String
    var sobre: String?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let sobre {
                Text(sobre.uppercased())
                    .font(tema.f(0.75, .semi))
                    .tracking(1)
                    .foregroundStyle(tema.esPoke ? p.texto.opacity(0.85) : (tema.esCua ? p.texto2 : tema.acento))
            }
            Text(texto)
                .font(fuente)
                .lineSpacing(tema.esPoke ? 6 : 0)
                .foregroundStyle(p.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fuente: Font {
        switch tema.estilo {
        case .poke: return tema.f(1.0, .normal, .pixel)
        case .cua: return tema.f(2.0, .medio, .titulo)
        case .nat: return tema.f(1.75, .negrita, .titulo)
        }
    }
}

/// Título de sección (h2) con enlace opcional a la derecha
struct TituloSeccion: View {
    let texto: String
    var enlace: String?
    var accion: (() -> Void)?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    init(_ texto: String, enlace: String? = nil, accion: (() -> Void)? = nil) {
        self.texto = texto
        self.enlace = enlace
        self.accion = accion
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                switch tema.estilo {
                case .poke:
                    Text(texto).font(tema.f(0.68, .normal, .pixel)).lineSpacing(4).foregroundStyle(p.texto)
                case .cua:
                    Text(texto.uppercased()).font(tema.f(0.8, .medio, .titulo)).tracking(2.4).foregroundStyle(p.texto2)
                case .nat:
                    Text(texto).font(tema.f(1.1, .negrita, .titulo)).foregroundStyle(p.texto)
                }
            }
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            if let enlace, let accion {
                Button(action: accion) {
                    Text(enlace).font(tema.f(0.875, .semi)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Subtítulo de un grupo de ajustes o de un mes
struct Subtitulo: View {
    let texto: String
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto.uppercased())
            .font(tema.esCua ? tema.f(0.8, .medio, .titulo) : tema.f(0.8, .negrita))
            .tracking(tema.esCua ? 2.4 : 0.8)
            .foregroundStyle(tema.esPoke ? p.texto : p.texto2)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Texto pequeño que indica la fuente de un dato
struct FuenteDato: View {
    let texto: String
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto).font(tema.f(0.75)).foregroundStyle(p.texto2).fixedSize(horizontal: false, vertical: true)
    }
}

/// Párrafo de texto de una ficha
struct Parrafo: View {
    let texto: String
    var negrita: String?
    @Environment(\.tema) private var tema

    init(_ texto: String, negrita: String? = nil) {
        self.texto = texto
        self.negrita = negrita
    }

    var body: some View {
        Group {
            if let negrita {
                Text(atribuido(negrita))
            } else {
                Text(texto)
            }
        }
        .font(tema.f(tema.esCua ? 1.05 : 0.92))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func atribuido(_ n: String) -> AttributedString {
        var a = AttributedString(n + " ")
        a.font = tema.f(tema.esCua ? 1.05 : 0.92, .negrita)
        var b = AttributedString(texto)
        b.font = tema.f(tema.esCua ? 1.05 : 0.92)
        return a + b
    }
}

// MARK: - Nombres

/// Nombre científico en cursiva, con los rangos (subsp., var.) y la autoría en redonda
struct NombreCientifico: View {
    let nombre: String
    var autor: String = ""
    var conAutor: Bool = true
    var em: CGFloat = 1
    var peso: Fuentes.Peso = .normal
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View { Text(texto) }

    private var texto: AttributedString {
        var s = AttributedString()
        for (i, t) in nombre.split(separator: " ").enumerated() {
            var a = AttributedString((i > 0 ? " " : "") + t)
            a.font = Cat.rangos.contains(String(t)) ? tema.f(em, peso, .cientifico) : tema.f(em, peso, .cientifico, cursiva: true)
            s += a
        }
        if conAutor && !autor.isEmpty {
            var a = AttributedString(" " + autor)
            a.font = tema.f(em, .normal, .cientifico)
            a.foregroundColor = p.texto2
            s += a
        }
        return s
    }
}

// MARK: - Insignias y chips

enum TipoInsignia: Equatable {
    case normal, invasora, amenaza, extinto, codigo
    case nivel(String)
    case uicn(String)
}

struct Insignia: View {
    let texto: String
    var tipo: TipoInsignia = .normal
    var pequena = false
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    init(_ texto: String, tipo: TipoInsignia = .normal, pequena: Bool = false) {
        self.texto = texto
        self.tipo = tipo
        self.pequena = pequena
    }

    var body: some View {
        let cs = colores
        let r: CGFloat = tema.esPoke ? 4 : (tema.esCua ? 0 : (pequena ? 6 : 8))
        Text(tema.esPoke ? texto.uppercased() : texto)
            .font(tema.f(pequena ? 0.68 : 0.75, tema.esCua ? .normal : .semi, cursiva: tema.esCua && !esUICN))
            .tracking(tema.esPoke ? 0.6 : 0)
            .foregroundStyle(cs.1)
            .lineLimit(2)
            .padding(.horizontal, pequena ? 7 : 9)
            .padding(.vertical, pequena ? 3 : 5)
            .background(cs.0, in: RoundedRectangle(cornerRadius: r))
            .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(cs.2 ?? .clear, lineWidth: 1))
            .shadow(color: .black.opacity(tema.esPoke ? 0.3 : 0), radius: 0, x: 0, y: tema.esPoke ? 2 : 0)
    }

    private var esUICN: Bool { if case .uicn = tipo { return true }; return false }

    private var colores: (Color, Color, Color?) {
        if case .uicn(let c) = tipo, let u = Cat.categoriaUICN(c) {
            return (Color(hex: u.color), Color(hex: u.texto), nil)
        }
        if tema.esCua {
            if case .nivel(let n) = tipo, n == "insular" || n == "canario" { return (.clear, tema.acento, tema.acento) }
            return (.clear, p.texto, p.texto2)
        }
        switch tipo {
        case .nivel("insular"): return (tema.acento, tema.acentoTxt, nil)
        case .nivel("canario"): return (tema.acentoSuave, tema.acentoTinta, nil)
        case .nivel("macaronesico"): return (tema.superficie2, tema.acentoTinta, nil)
        case .nivel("introducido"): return (Color(hex: "#F3E5D4"), Color(hex: "#5A3A14"), nil)
        case .invasora: return (Color(hex: "#F6D6D2"), Color(hex: "#7A1D14"), nil)
        case .amenaza: return (Color(hex: "#FFE1CF"), Color(hex: "#6A2A06"), nil)
        case .extinto: return (Color(hex: "#2A2D2B"), Color(hex: "#F4F5F1"), nil)
        default: return (tema.superficie2, p.texto, nil)
        }
    }
}

/// Insignias de una especie en las listas (endemicidad, invasora, amenaza, extinta)
struct InsigniasEspecie: View {
    let e: Especie
    var pequena = true

    var body: some View {
        Flujo(espacio: 6) {
            Insignia(Cat.nombreNivel[e.nivel] ?? e.nivel, tipo: .nivel(e.nivel), pequena: pequena)
            if e.origen == "ISI" { Insignia("Invasora", tipo: .invasora, pequena: pequena) }
            if e.origen == "ISP" { Insignia("Potencialmente invasora", tipo: .invasora, pequena: pequena) }
            if ["CR", "EN", "VU"].contains(e.uicn) { Insignia("UICN \(e.uicn)", tipo: .uicn(e.uicn), pequena: pequena) }
            if let a = (e.catCanario + e.catEspanol).first(where: { Especie.esCategoriaAmenaza($0) }) {
                Insignia(a, tipo: .amenaza, pequena: pequena)
            }
            if e.esExtinta { Insignia("Extinto", tipo: .extinto, pequena: pequena) }
        }
    }
}

/// Botón redondeado para filtros y opciones
struct Chip: View {
    let texto: String
    var activo = false
    var oscuro = false
    var icono: String?
    var quitar = false
    let accion: () -> Void
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 6) {
                if let icono { Icono(icono, tam: 16) }
                Text(texto)
                    .font(tema.esCua ? tema.f(1, .normal, cursiva: true) : tema.f(0.82, .semi))
                    .lineLimit(1)
                if quitar { Icono("cerrar", tam: 13).opacity(0.8) }
            }
            .padding(.horizontal, tema.esCua ? 6 : 12)
            .frame(minHeight: 36)
            .foregroundStyle(colorTexto)
            .background(colorFondo, in: forma)
            .overlay(forma.strokeBorder(colorBorde, lineWidth: 1))
            .overlay(alignment: .bottom) {
                if tema.esCua && activo { Rectangle().fill(tema.acento).frame(height: 1) }
            }
            .contentShape(forma)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activo ? .isSelected : [])
    }

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: tema.esPoke ? 6 : (tema.esCua ? 0 : 18), style: .continuous)
    }
    private var colorFondo: Color {
        switch tema.estilo {
        case .poke: return activo ? tema.tecla : tema.oscuroPoke
        case .cua: return .clear
        case .nat: return oscuro ? p.texto : (activo ? tema.acento : tema.superficie)
        }
    }
    private var colorTexto: Color {
        switch tema.estilo {
        case .poke: return .white
        case .cua: return activo ? tema.acento : p.texto
        case .nat: return oscuro ? tema.fondo : (activo ? tema.acentoTxt : p.texto)
        }
    }
    private var colorBorde: Color {
        switch tema.estilo {
        case .poke: return activo ? tema.tecla : tema.oscuroPoke
        case .cua: return .clear
        case .nat: return oscuro ? p.texto : (activo ? tema.acento : tema.borde)
        }
    }
}

// MARK: - Botones

enum TipoBoton { case principal, secundario, peligro }

struct EstiloBoton: ButtonStyle {
    var tipo: TipoBoton = .principal

    func makeBody(configuration: Configuration) -> some View {
        CuerpoBoton(configuration: configuration, tipo: tipo)
    }

    private struct CuerpoBoton: View {
        let configuration: ButtonStyleConfiguration
        let tipo: TipoBoton
        @Environment(\.tema) private var tema
        @Environment(\.paleta) private var p
        @Environment(\.isEnabled) private var activo

        var body: some View {
            let r: CGFloat = tema.esPoke ? 8 : (tema.esCua ? 0 : tema.radio * 0.75)
            let forma = RoundedRectangle(cornerRadius: r, style: .continuous)
            configuration.label
                .font(tema.esCua ? tema.f(1.05, .medio) : tema.f(1, .negrita))
                .textCase(tema.esCua ? .uppercase : nil)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 18)
                .foregroundStyle(texto)
                .background(fondo, in: forma)
                .overlay(forma.strokeBorder(borde, lineWidth: 1))
                .shadow(color: .black.opacity(tema.esPoke && tipo == .principal ? 0.4 : 0), radius: 0, x: 0, y: 3)
                .opacity(activo ? (configuration.isPressed ? 0.7 : 1) : 0.5)
                .contentShape(forma)
        }

        private var fondo: Color {
            switch tipo {
            case .peligro: return .clear
            case .secundario: return tema.esCua ? .clear : tema.superficie2
            case .principal: return tema.esPoke ? tema.oscuroPoke : (tema.esCua ? .clear : tema.acento)
            }
        }
        private var texto: Color {
            switch tipo {
            case .peligro: return tema.peligro
            case .secundario: return p.texto
            case .principal: return tema.esPoke ? .white : (tema.esCua ? p.texto : tema.acentoTxt)
            }
        }
        private var borde: Color {
            switch tipo {
            case .peligro: return tema.peligro
            case .secundario: return tema.esCua ? p.texto : .clear
            case .principal: return tema.esCua ? p.texto : .clear
            }
        }
    }
}

/// Botón redondo con icono (44 × 44)
struct BotonIcono: View {
    let icono: String
    let etiqueta: String
    var sobreFoto = false
    let accion: () -> Void
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        Button(action: accion) {
            Icono(icono, tam: 22)
                .frame(width: 44, height: 44)
                .foregroundStyle(color)
                .background(fondo, in: Circle())
                .overlay(Circle().strokeBorder(borde, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
    }

    private var fondo: Color {
        if tema.esPoke { return tema.oscuroPoke }
        if sobreFoto { return Color.white.opacity(0.92) }
        return tema.esCua ? .clear : tema.superficie
    }
    private var color: Color {
        if tema.esPoke { return .white }
        return sobreFoto ? Color(hex: "#1C211B") : p.texto
    }
    private var borde: Color {
        if tema.esPoke || sobreFoto { return .clear }
        return tema.esCua ? p.texto : tema.borde
    }
}

// MARK: - Especies

/// Foto pequeña de una especie con el icono de su grupo debajo
struct Miniatura: View {
    let e: Especie
    var ancho: CGFloat = 56
    var alto: CGFloat = 56
    var px: Int = 120
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Environment(Ajustes.self) private var ajustes

    var body: some View {
        let r: CGFloat = tema.esPoke ? 4 : (tema.esCua ? 0 : tema.radioP * 1.2)
        let forma = RoundedRectangle(cornerRadius: r, style: .continuous)
        let foto = URLsFotos.principal(e, biota: ajustes.d.fotosBiota, libres: ajustes.d.fotosLibres, ancho: px)
        ZStack {
            Rectangle().fill(tema.esPoke || tema.esCua ? Color.clear : tema.acentoSuave)
            Icono(Cat.icono(grupo: e.grupo), tam: min(ancho, alto) * 0.42)
                .foregroundStyle(tema.esPoke || tema.esCua ? p.texto : tema.acento)
            if let foto {
                ImagenRemota(url: foto.url, maxPx: CGFloat(px) * 2.5)
                    .frame(width: ancho, height: alto)
            }
        }
        .frame(width: ancho, height: alto)
        .clipShape(forma)
        .overlay(forma.strokeBorder(tema.esPoke ? p.texto : (tema.esCua ? p.texto : .clear), lineWidth: tema.esPoke ? 2 : 1))
    }
}

/// Círculo que marca si ya has visto la especie
struct MarcaVista: View {
    let vista: Bool
    @Environment(\.tema) private var tema

    var body: some View {
        ZStack {
            Circle().fill(vista ? tema.acento : Color.clear)
            Circle().strokeBorder(vista ? tema.acento : tema.borde, lineWidth: 2)
            if vista { Icono("check", tam: 14, grosor: 3).foregroundStyle(tema.acentoTxt) }
        }
        .frame(width: 26, height: 26)
        .accessibilityLabel(vista ? "Vista" : "No vista")
    }
}

/// Fila de una especie en las listas
struct FilaEspecie: View {
    let e: Especie
    var numero: String
    var vista: Bool
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Environment(Ajustes.self) private var ajustes

    var body: some View {
        HStack(spacing: 12) {
            Miniatura(e: e)
            VStack(alignment: .leading, spacing: 2) {
                Text(numero).font(tema.f(0.75, .semi)).foregroundStyle(p.texto2)
                Text(tema.esPoke ? e.nombreComun.uppercased() : e.nombreComun)
                    .font(fuenteNombre)
                    .foregroundStyle(p.texto)
                    .lineLimit(2)
                NombreCientifico(nombre: e.nombre, autor: e.autor, conAutor: ajustes.d.autoria, em: 0.82)
                    .foregroundStyle(p.texto2)
                    .lineLimit(1)
                InsigniasEspecie(e: e).padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MarcaVista(vista: vista)
        }
        .padding(.vertical, 10 * tema.esp)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var fuenteNombre: Font {
        switch tema.estilo {
        case .poke: return tema.f(1.3, .normal, .lcd)
        case .cua: return tema.f(1.1, .medio)
        case .nat: return tema.f(1, .negrita)
        }
    }
}

/// Separador entre filas de una lista
struct Separador: View {
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        if tema.esPoke {
            Line()
                .stroke(p.texto.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .frame(height: 2)
        } else {
            Rectangle().fill(tema.esCua ? tema.borde : tema.borde2).frame(height: 1)
        }
    }

    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
    }
}

// MARK: - Varios

struct BarraProgreso: View {
    let valor: Double
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(tema.superficie2)
                Capsule().fill(p.dentro || !tema.esPoke ? tema.acento : p.texto)
                    .frame(width: g.size.width * max(0, min(1, valor)))
            }
        }
        .frame(height: 8)
        .accessibilityValue("\(Int((valor * 100).rounded())) %")
    }
}

/// Dato destacado de la ficha (Islas, Grupo, Tamaño…)
struct Hecho: View {
    let icono: String
    let k: String
    let v: String
    let s: String
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Icono(icono, tam: 16).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                Text(k).font(tema.f(0.75, .semi)).foregroundStyle(p.texto2)
            }
            Text(tema.esPoke ? v.uppercased() : v)
                .font(tema.esPoke ? tema.f(1.3, .normal, .lcd) : tema.f(1.05, .negrita))
                .foregroundStyle(p.texto)
                .fixedSize(horizontal: false, vertical: true)
            if !s.isEmpty {
                Text(s).font(tema.f(0.75)).foregroundStyle(p.texto2).lineLimit(3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Fila «clave · valor» de la ficha (rasgos, introducción…)
struct FilaDato: View {
    let k: String
    let v: String
    var fuente: String?
    var url: String?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(k).font(tema.f(0.82)).foregroundStyle(p.texto2)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(v).font(tema.f(0.9, .semi)).foregroundStyle(p.texto).fixedSize(horizontal: false, vertical: true)
                if let fuente, !fuente.isEmpty {
                    if let url, let u = URL(string: url) {
                        Link(destination: u) { Text(fuente).underline().font(tema.f(0.7)).foregroundStyle(p.texto2) }
                    } else {
                        Text(fuente).font(tema.f(0.7)).foregroundStyle(p.texto2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.vertical, 8)
    }
}

/// Distribuye sus elementos en líneas (como flex-wrap)
struct Flujo: Layout {
    var espacio: CGFloat = 8
    var espacioLinea: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, alto: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: ancho, height: nil))
            if x > 0 && x + t.width > ancho {
                x = 0
                y += alto + (espacioLinea ?? espacio)
                alto = 0
            }
            x += t.width + espacio
            maxX = max(maxX, x - espacio)
            alto = max(alto, t.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: subviews.isEmpty ? 0 : y + alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alto: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + t.width > bounds.maxX {
                x = bounds.minX
                y += alto + (espacioLinea ?? espacio)
                alto = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: t.width, height: t.height))
            x += t.width + espacio
            alto = max(alto, t.height)
        }
    }
}

/// Fondo de toda la app: color, y textura de papel o malla de puntos si se elige
struct FondoApp: View {
    @Environment(\.tema) private var tema

    var body: some View {
        ZStack {
            tema.fondoPantalla
            if tema.c.textura == "Textura de papel" || tema.c.textura == "Malla de puntos" {
                let papel = tema.c.textura == "Textura de papel"
                let puntos = papel ? Color.black.opacity(0.035) : tema.borde
                Canvas { ctx, size in
                    let paso: CGFloat = papel ? 7 : 16
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.2, height: 2.2)), with: .color(puntos))
                            x += paso
                        }
                        y += paso
                    }
                    if papel {
                        var y2: CGFloat = 5
                        while y2 < size.height {
                            var x2: CGFloat = 3
                            while x2 < size.width {
                                ctx.fill(Path(ellipseIn: CGRect(x: x2, y: y2, width: 2, height: 2)), with: .color(Color.black.opacity(0.025)))
                                x2 += 11
                            }
                            y2 += 11
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

/// Mensaje centrado para listas vacías o errores
struct Vacio: View {
    let icono: String
    let texto: String
    var detalle: String?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        VStack(spacing: 10) {
            Icono(icono, tam: 42).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
            Text(texto).font(tema.f(1)).multilineTextAlignment(.center)
            if let detalle { Text(detalle).font(tema.f(0.8)).multilineTextAlignment(.center) }
        }
        .foregroundStyle(p.texto2)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

/// Decoración de la carcasa del estilo Pokédex (lente azul, luces y marca)
struct DecoracionPokedex: View {
    @Environment(\.tema) private var tema

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(.white).frame(width: 60, height: 60).shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 2)
                Circle().fill(Color(hex: "#2F7FD3")).frame(width: 46, height: 46)
                    .overlay(Circle().strokeBorder(Color(hex: "#1B4E86"), lineWidth: 3))
                Circle().fill(Color(hex: "#A8D3FF")).frame(width: 13, height: 13).offset(x: -8, y: -8)
            }
            HStack(spacing: 6) {
                ForEach(["#FF6B6B", "#FFD23F", "#4CC36B"], id: \.self) { c in
                    Circle().fill(Color(hex: c)).frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 2))
                }
            }
            .frame(maxHeight: 60, alignment: .top)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("POKÉDEX").font(Fuentes.fuente("Press Start 2P", tam: 13))
                Text("CANARIA").font(Fuentes.fuente("Press Start 2P", tam: 9)).opacity(0.85)
            }
            .foregroundStyle(tema.carcasaTxt)
        }
        .padding(.top, 4)
        .padding(.horizontal, 2)
        .accessibilityHidden(true)
    }
}
