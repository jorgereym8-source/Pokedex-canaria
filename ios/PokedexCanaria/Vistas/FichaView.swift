import SwiftUI
import SwiftData

/// Ficha completa de una especie
struct FichaView: View {
    let codigo: String
    @Environment(Almacen.self) var almacen
    @Environment(Ajustes.self) var ajustes
    @Environment(Navegacion.self) var nav
    @Environment(\.tema) var tema
    @Environment(\.paleta) var p
    @Environment(\.dismiss) private var cerrar
    @Query var avs: [Avistamiento]
    @State private var ficha: Ficha?
    @State private var error: String?
    @State private var nuevo = false
    @State var detalle: Avistamiento?
    @State private var foto = 0

    init(codigo: String) {
        self.codigo = codigo
        _avs = Query(filter: #Predicate<Avistamiento> { $0.codigo == codigo }, sort: \Avistamiento.fecha, order: .reverse)
    }

    var body: some View {
        Group {
            if let e = almacen.especie(codigo) {
                if let f = ficha {
                    contenido(e, f)
                } else if let error {
                    VStack(alignment: .leading) {
                        BotonIcono(icono: "atras", etiqueta: "Volver") { cerrar() }
                        Vacio(icono: "alerta", texto: error)
                        Spacer()
                    }
                    .padding(tema.margen)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Cargando ficha…").font(tema.f(1)).foregroundStyle(p.texto2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(alignment: .leading) {
                    BotonIcono(icono: "atras", etiqueta: "Volver") { cerrar() }
                    Vacio(icono: "alerta", texto: "No encuentro esa especie.")
                    Spacer()
                }
                .padding(tema.margen)
            }
        }
        .pantalla()
        .task(id: codigo) { @MainActor in
            do {
                ficha = try await almacen.ficha(codigo)
            } catch {
                self.error = error.localizedDescription
            }
        }
        .sheet(isPresented: $nuevo) {
            if let e = almacen.especie(codigo) {
                NuevoAvistamientoView(especie: e)
                    .environment(\.tema, tema)
                    .environment(\.paleta, tema.fuera)
            }
        }
        .sheet(item: $detalle) { a in
            DetalleAvistamientoView(av: a)
                .environment(\.tema, tema)
                .environment(\.paleta, tema.fuera)
        }
    }

    // MARK: - Contenido

    private func contenido(_ e: Especie, _ f: Ficha) -> some View {
        GeometryReader { g in
            let arriba = g.safeAreaInsets.top
            ScrollView {
                VStack(alignment: .leading, spacing: tema.hueco) {
                    if tema.esPoke {
                        DecoracionPokedex()
                            .padding(.horizontal, tema.margen)
                            .padding(.top, arriba + 8)
                    }
                    heroe(e, f, arriba: tema.esPoke ? 0 : arriba)
                    VStack(alignment: .leading, spacing: tema.hueco) {
                        titulo(e, f)
                        insignias(e, f)
                        hechos(e, f)
                        seccionTamano(e, f)
                        seccionBiologia(f)
                        seccionSonidos(f)
                        seccionDistribucion(e, f)
                        seccionIntroduccion(e, f)
                        seccionHabitat(f)
                        seccionesCentinela(f)
                        CalendarioView(e: e)
                        seccionProteccion(f)
                        seccionVulnerabilidad(f)
                        seccionEtimologia(f)
                        seccionTaxonomia(f)
                        seccionGenero(e)
                        seccionWebs(e, f)
                        seccionAvistamientos(e)
                        seccionFuentes(f)
                    }
                    .padding(.horizontal, tema.margen)
                }
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Fotos

    private func heroe(_ e: Especie, _ f: Ficha, arriba: CGFloat) -> some View {
        let fotos = URLsFotos.deFicha(f, codigo: codigo, biota: ajustes.d.fotosBiota, libres: ajustes.d.fotosLibres)
        let hay = f.imagenes.count + f.fotosLibres.count
        let alto = 340 + arriba
        return ZStack(alignment: .bottomLeading) {
            Rectangle().fill(tema.esPoke ? tema.fondo : (tema.esCua ? Color.clear : tema.acentoSuave))
            VStack(spacing: 8) {
                Icono(Cat.icono(grupo: e.grupo), tam: 64, grosor: 1.2)
                if fotos.isEmpty {
                    Text(hay > 0 ? "Fotos desactivadas en Ajustes" : "Sin fotos").font(tema.f(0.8))
                    if let evc = f.evc, let u = URL(string: evc.url) {
                        Link(destination: u) {
                            Text("Ver fotos en Especies Vegetales en Canarias ›")
                                .font(tema.f(0.84, .semi))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(tema.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(tema.borde, lineWidth: 1))
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .foregroundStyle(tema.esPoke ? tema.texto : (tema.esCua ? tema.texto : tema.acento))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, arriba)
            if !fotos.isEmpty {
                TabView(selection: $foto) {
                    ForEach(fotos.indices, id: \.self) { i in
                        ZStack(alignment: .bottomTrailing) {
                            ImagenRemota(url: fotos[i].url, maxPx: 1500)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                            pieFoto(fotos[i])
                        }
                        .tag(i)
                        .accessibilityLabel("\(e.nombreComun), foto \(i + 1)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                Text("\(min(foto, fotos.count - 1) + 1) / \(fotos.count)")
                    .font(tema.f(0.75, .semi))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .padding(.leading, 16).padding(.bottom, 14)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: alto)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            if tema.esPoke { Rectangle().fill(tema.oscuroPoke).frame(height: 4) }
            if tema.esCua { Rectangle().fill(tema.texto).frame(height: 1) }
        }
        .overlay(alignment: .top) {
            HStack {
                BotonIcono(icono: "atras", etiqueta: "Volver", sobreFoto: true) { cerrar() }
                Spacer()
                if let u = URL(string: Cat.web + "#/especie/\(codigo)") {
                    ShareLink(item: u, subject: Text(e.nombreComun), message: Text("\(e.nombreComun) (\(e.nombre)) en la Pokédex Canaria")) {
                        Icono("compartir", tam: 22)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(tema.esPoke ? Color.white : Color(hex: "#1C211B"))
                            .background(tema.esPoke ? tema.oscuroPoke : Color.white.opacity(0.92), in: Circle())
                    }
                    .accessibilityLabel("Compartir")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, arriba + 12)
        }
        .onChange(of: codigo) { _, _ in foto = 0 }
    }

    @ViewBuilder
    private func pieFoto(_ ft: Foto) -> some View {
        let t = Text(ft.pie)
            .font(tema.f(0.72))
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.black.opacity(0.62), in: Capsule())
        Group {
            if let u = ft.enlace { Link(destination: u) { t } } else { t }
        }
        .frame(maxWidth: 280, alignment: .trailing)
        .padding(.trailing, 12).padding(.bottom, 12)
    }

    // MARK: Título

    private func titulo(_ e: Especie, _ f: Ficha) -> some View {
        let otros = ajustes.d.nombres == "Todos" ? Array(e.comunes.dropFirst()) : []
        let familia = f.taxonomia.first { $0.rango == "Familia" }?.valor ?? (e.familia.isEmpty ? e.grupo : e.familia)
        let regionales = Cat.islasOrden.compactMap { k in e.regional[k].map { "\(Cat.sigla[k] ?? k) \(String(format: "%04d", $0))" } }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    Text(numeroPokedex(e.numero))
                        .font(tema.f(0.75, tema.esCua ? .normal : .negrita))
                        .tracking(tema.esCua ? 1.2 : 0)
                        .foregroundStyle(tema.esPoke ? Color.white : (tema.esCua ? p.texto2 : tema.fondo))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(tema.esPoke ? tema.oscuroPoke : (tema.esCua ? Color.clear : p.texto), in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : 6))
                        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(tema.esCua ? p.texto2 : .clear, lineWidth: 1))
                    Text(familia).font(tema.f(0.82)).foregroundStyle(p.texto2).lineLimit(1)
                }
                Spacer(minLength: 4)
                BotonVista(n: avs.count) { nuevo = true }
            }
            Text(tema.esPoke ? e.nombreComun.uppercased() : e.nombreComun)
                .font(fuenteNombre)
                .lineSpacing(tema.esPoke ? 6 : 0)
                .foregroundStyle(p.texto)
                .fixedSize(horizontal: false, vertical: true)
            NombreCientifico(nombre: f.nombre.isEmpty ? e.nombre : f.nombre, autor: f.autor.isEmpty ? e.autor : f.autor,
                             conAutor: ajustes.d.autoria, em: 1.15)
                .foregroundStyle(p.texto)
            if !otros.isEmpty {
                Text("Otros nombres: \(otros.joined(separator: " · "))").font(tema.f(0.8))
            }
            Text("Código Biota \(codigo)\(f.validez.isEmpty ? "" : " · \(f.validez)")\(f.status == "Extinto" ? " · Extinto" : "")")
                .font(tema.f(0.8)).foregroundStyle(p.texto2)
            if f.fichaPendiente {
                Text("Ficha completa de Biota en camino: se está descargando en las actualizaciones automáticas.")
                    .font(tema.f(0.8)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
            }
            if !regionales.isEmpty {
                Text("Pokédex regional: \(regionales.joined(separator: " · "))").font(tema.f(0.8)).foregroundStyle(p.texto2)
            }
        }
    }

    private var fuenteNombre: Font {
        switch tema.estilo {
        case .poke: return tema.f(1.05, .normal, .pixel)
        case .cua: return tema.f(2.1, .medio, .titulo)
        case .nat: return tema.f(1.75, .negrita, .titulo)
        }
    }

    private func insignias(_ e: Especie, _ f: Ficha) -> some View {
        let orig = f.origen?.codigo.isEmpty == false ? f.origen!.codigo : e.origen
        let nombreOrigen = (f.origen?.nombre.isEmpty == false ? f.origen!.nombre : nil) ?? Cat.origenes[orig] ?? orig
        var cats: [String] = []
        for c in e.catCanario.map({ "C. Canario: \($0)" }) + e.catEspanol.map({ "C. Español: \($0)" }) where !cats.contains(c) { cats.append(c) }
        return Flujo(espacio: 6) {
            Insignia(Cat.nombreNivel[e.nivel] ?? e.nivel, tipo: .nivel(e.nivel))
            if let u = f.uicn {
                Insignia("UICN · \(u.categoria) (\(u.codigo))", tipo: .uicn(u.codigo))
            }
            if !orig.isEmpty || !nombreOrigen.isEmpty {
                Insignia(orig.isEmpty ? nombreOrigen : "\(nombreOrigen) (\(orig))")
            }
            if orig == "ISI" { Insignia("Invasora", tipo: .invasora) }
            if orig == "ISP" { Insignia("Potencialmente invasora", tipo: .invasora) }
            ForEach(cats, id: \.self) { c in
                Insignia(c, tipo: Especie.esCategoriaAmenaza(c) ? .amenaza : .normal)
            }
        }
    }

    private func hechos(_ e: Especie, _ f: Ficha) -> some View {
        let islas = e.islas
        let hay = f.imagenes.count + f.fotosLibres.count
        let h1 = (icono: "pin", k: "Islas", v: "\(islas.count) de 7", s: islas.isEmpty ? "—" : islas.map { Cat.sigla[$0] ?? $0 }.joined(separator: " · "))
        let h2 = (icono: Cat.icono(grupo: e.grupo), k: "Grupo", v: e.grupo, s: e.subgrupo ?? f.clase)
        let h3: (icono: String, k: String, v: String, s: String)
        if let t = f.tamano {
            h3 = ("regla", conMayuscula(t.tipo), Medidas.textoTamano(t), t.fuente)
        } else {
            h3 = ("montana", "Medio", f.medio.isEmpty ? e.medio : f.medio, f.taxonomia.first { $0.rango == "Clase" }?.valor ?? "")
        }
        let h4: (icono: String, k: String, v: String, s: String)
        if let l = f.longevidad {
            h4 = ("reloj", "Longevidad", Medidas.anos(l.anos), [l.tipo, l.origen].filter { !$0.isEmpty }.joined(separator: ", "))
        } else if let c = f.ciclo {
            let v = c.valor.replacingOccurrences(of: #" \(.*\)"#, with: "", options: .regularExpression)
            h4 = ("reloj", "Ciclo de vida", v, c.fuente)
        } else if let ps = f.peso {
            h4 = ("regla", "Peso", Medidas.peso(ps.kg), ps.fuente)
        } else {
            let n = avs.count
            h4 = ("camara", "Fotos", String(hay), n > 0 ? "\(n) avistamiento\(n > 1 ? "s" : "") tuyo\(n > 1 ? "s" : "")" : "Aún no la has visto")
        }
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Hecho(icono: h1.icono, k: h1.k, v: h1.v, s: h1.s).tarjeta(radio: tema.radio * 0.85)
                Hecho(icono: h2.icono, k: h2.k, v: h2.v, s: h2.s).tarjeta(radio: tema.radio * 0.85)
            }
            GridRow {
                Hecho(icono: h3.icono, k: h3.k, v: h3.v, s: h3.s).tarjeta(radio: tema.radio * 0.85)
                Hecho(icono: h4.icono, k: h4.k, v: h4.v, s: h4.s).tarjeta(radio: tema.radio * 0.85)
            }
        }
    }
}

/// «La he visto» / «Vista · 2»
struct BotonVista: View {
    let n: Int
    let accion: () -> Void
    @Environment(\.tema) private var tema

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 6) {
                if !tema.esCua { Icono(n > 0 ? "check" : "vistas", tam: 18) }
                Text(n > 0 ? (n > 1 ? "Vista · \(n)" : "Vista") : "La he visto")
            }
            .font(tema.esCua ? tema.f(1.35, .semi, .mano) : tema.f(0.875, .semi))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(texto)
            .background(fondo, in: Capsule())
            .overlay(Capsule().strokeBorder(borde, lineWidth: tema.esPoke ? 3 : 1.5))
            .rotationEffect(.degrees(tema.esCua ? -3 : 0))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var fondo: Color {
        switch tema.estilo {
        case .poke: return n > 0 ? Color(hex: "#4CC36B") : tema.oscuroPoke
        case .cua: return .clear
        case .nat: return n > 0 ? tema.acento : tema.superficie
        }
    }
    private var texto: Color {
        switch tema.estilo {
        case .poke: return n > 0 ? Color(hex: "#17230F") : .white
        case .cua: return tema.acento
        case .nat: return n > 0 ? tema.acentoTxt : tema.acento
        }
    }
    private var borde: Color {
        switch tema.estilo {
        case .poke: return tema.oscuroPoke
        case .cua: return .clear
        case .nat: return n > 0 ? .clear : tema.acento
        }
    }
}
