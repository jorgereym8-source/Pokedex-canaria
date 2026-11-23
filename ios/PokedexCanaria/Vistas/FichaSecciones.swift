import SwiftUI

/// Trozos de texto con negrita y enlaces (para las líneas de las fichas)
enum Trozo {
    case texto(String)
    case negrita(String)
    case cursiva(String)
    case enlace(String, String?)
}

extension Tema {
    func rico(_ trozos: [Trozo], em: CGFloat = 0.92, color2: Color? = nil) -> AttributedString {
        var s = AttributedString()
        for t in trozos {
            switch t {
            case .texto(let x):
                var a = AttributedString(x)
                a.font = f(em)
                s += a
            case .negrita(let x):
                var a = AttributedString(x)
                a.font = f(em, .negrita)
                s += a
            case .cursiva(let x):
                var a = AttributedString(x)
                a.font = f(em, .normal, .cientifico, cursiva: true)
                s += a
            case .enlace(let x, let u):
                var a = AttributedString(x)
                a.font = f(em)
                if let u, let url = URL(string: u) {
                    a.link = url
                    a.underlineStyle = .single
                }
                s += a
            }
        }
        return s
    }
}

extension FichaView {
    // MARK: Tamaño y vida

    @ViewBuilder
    func seccionTamano(_ e: Especie, _ f: Ficha) -> some View {
        if f.tamano != nil || f.peso != nil || f.longevidad != nil || f.ciclo != nil {
            Seccion("Tamaño" + (f.longevidad != nil || f.ciclo != nil ? " y vida" : "")) {
                if let t = f.tamano {
                    DiagramaTamano(forma: f.forma?.valor ?? (e.esFlora ? "arbusto" : "mamifero"), min: t.min, max: t.max, alturaCm: ajustes.d.altura)
                        .padding(.vertical, 4)
                    Text(tema.rico([.negrita(conMayuscula(t.tipo) + ": "), .texto(Medidas.textoTamano(t).lowercased() + " · "),
                                    .enlace(t.fuente, t.url), .texto(t.nivel == "especie" ? " (dato de la especie)" : "")]))
                    if let c = t.cita {
                        Text("«\(c)»").font(tema.f(0.8, cursiva: true)).foregroundStyle(p.texto2)
                    }
                }
                if let ps = f.peso {
                    Text(tema.rico([.negrita("Peso \(ps.tipo): "), .texto(Medidas.peso(ps.kg) + " · "), .enlace(ps.fuente, ps.url)]))
                }
                if let l = f.longevidad {
                    Text(tema.rico([.negrita("Longevidad \(l.tipo): "), .texto(Medidas.anos(l.anos) + (l.origen.isEmpty ? "" : " (\(l.origen))") + " · "),
                                    .enlace(l.fuente, l.url)]))
                }
                if let c = f.ciclo {
                    Text(tema.rico([.negrita("Ciclo de vida: "), .texto("\(c.valor) · \(c.fuente)")]))
                }
            }
        }
    }

    // MARK: Biología

    @ViewBuilder
    func seccionBiologia(_ f: Ficha) -> some View {
        let filas: [Ficha.Rasgo] = f.rasgos + (f.tallaMinima.map {
            [Ficha.Rasgo(grupo: "Pesca", k: "Talla mínima legal (caladero canario)", v: "\($0.valor) · \($0.especieNorma)", fuente: "BOE · RD 560/1995", url: $0.url)]
        } ?? [])
        if !filas.isEmpty {
            let grupos = filas.reduce(into: [String]()) { if !$0.contains($1.grupo) { $0.append($1.grupo) } }
            Seccion("Biología") {
                ForEach(grupos, id: \.self) { g in
                    Text(g.uppercased()).font(tema.f(0.78, .negrita)).tracking(0.8).foregroundStyle(p.texto2).padding(.top, 4)
                    VStack(spacing: 0) {
                        let xs = filas.filter { $0.grupo == g }
                        ForEach(xs.indices, id: \.self) { i in
                            FilaDato(k: xs[i].k, v: xs[i].v, fuente: xs[i].fuente, url: xs[i].url)
                            if i < xs.count - 1 { Separador() }
                        }
                    }
                }
                if f.tallaMinima != nil {
                    FuenteDato("La talla mínima procede del texto consolidado del BOE; comprueba la normativa vigente (también la europea y la de pesca recreativa) antes de pescar.")
                }
            }
        }
    }

    // MARK: Sonidos

    @ViewBuilder
    func seccionSonidos(_ f: Ficha) -> some View {
        if !f.sonidos.isEmpty {
            Seccion("Sonidos") {
                ForEach(f.sonidos, id: \.self) { s in FilaSonido(s: s) }
            }
        }
    }

    // MARK: Distribución

    func seccionDistribucion(_ e: Especie, _ f: Ficha) -> some View {
        let pr = presencia(e.presenciaIslas)
        let presente = tema.esPoke ? p.texto : tema.acento
        return Seccion("Distribución") {
            MapaIslas(presenciaIslas: e.presenciaIslas)
            Flujo(espacio: 14, espacioLinea: 6) {
                Leyenda(texto: "Presente", relleno: presente)
                Leyenda(texto: "Dudosa", relleno: tema.acentoSuave, borde: presente, discontinuo: true)
                Leyenda(texto: "Traslocada", relleno: MapaIslas.colorTraslocada)
                Leyenda(texto: "Extinta", relleno: MapaIslas.colorExtinta)
                Leyenda(texto: "Sin citas", relleno: .clear, borde: MapaIslas.colorExtinta)
                if pr["M"] != nil {
                    Leyenda(texto: "En aguas de Canarias", relleno: tema.c.superficie.mezclar(RGB.hex("#3F87B0"), 0.3).color)
                }
            }
            FuenteDato("Contorno de las islas: © OpenStreetMap. Los islotes se colorean con su isla (La Graciosa, Alegranza y Montaña Clara con Lanzarote; Lobos con Fuerteventura).")
            if let m = f.seccion("Distribución mundial") { Parrafo(m, negrita: "Mundial:") }
            if let c = f.seccion("Distribución en Canarias") { Parrafo(c, negrita: "En Canarias:") }
            if let pk = f.mapaPk, let u = URL(string: "\(Cat.biota)/minMap?especiePk=\(pk)&width=525&height=250") {
                ImagenRemota(url: u, maxPx: 1050, modo: .fit)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(tema.superficie2)
                    .clipShape(RoundedRectangle(cornerRadius: tema.radioP))
                    .overlay(RoundedRectangle(cornerRadius: tema.radioP).strokeBorder(tema.borde, lineWidth: 1))
                    .accessibilityLabel("Mapa de distribución de Biota en cuadrículas")
            }
            if let u = URL(string: "\(Cat.biota)/especie/\(e.codigo)") {
                Link(destination: u) {
                    Text("Ver las cuadrículas de distribución en Biota ›").font(tema.f(0.8, .semi)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                }
            }
            FuenteDato("Fuente: Biota\(f.seccion("Distribución en Canarias") != nil ? " · Centinela" : "")")
            if let a = f.altitud {
                Text("ALTITUD").font(tema.f(0.78, .negrita)).tracking(0.8).foregroundStyle(p.texto2).padding(.top, 4)
                Text(tema.rico([.negrita("\(miles(a.p5)) m – \(miles(a.p95)) m"),
                                .texto(" (el 90 % central de \(miles(a.n)) registros georreferenciados; extremos \(miles(a.min)) m – \(miles(a.max)) m)")]))
                Text(tema.rico([.texto("Altitud medida en el modelo del terreno Copernicus GLO-90 en cada registro de GBIF con precisión de 1 km o mejor. "),
                                .enlace("Ver registros", a.url)], em: 0.75))
                    .foregroundStyle(p.texto2)
            }
            if let w = f.mundo {
                Text("DISTRIBUCIÓN MUNDIAL").font(tema.f(0.78, .negrita)).tracking(0.8).foregroundStyle(p.texto2).padding(.top, 4)
                if !w.nativa.isEmpty { Parrafo(w.nativa.joined(separator: ", "), negrita: "Nativa:") }
                if !w.introducida.isEmpty { Parrafo(w.introducida.joined(separator: ", "), negrita: "Introducida:") }
                Text(tema.rico([.texto("Fuente: "), .enlace("WCVP · Plants of the World Online (Kew)", w.url),
                                .texto(w.nivel == "especie" ? " · dato de la especie" : ""), .texto(w.nombre.map { " · como \($0)" } ?? "")], em: 0.75))
                    .foregroundStyle(p.texto2)
            }
            if let clave = f.gbifClave {
                let am = e.esAmenazada
                Text("REGISTROS EN GBIF").font(tema.f(0.78, .negrita)).tracking(0.8).foregroundStyle(p.texto2).padding(.top, 4)
                MapaGBIF(clave: clave, amenazada: am)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: tema.radioP))
                    .overlay(RoundedRectangle(cornerRadius: tema.radioP).strokeBorder(tema.borde, lineWidth: 1))
                Text(tema.rico([.texto("Densidad de registros de GBIF\(am ? " en celdas grandes para no revelar localidades de una especie amenazada" : ""). "),
                                .enlace("Ver en GBIF", "https://www.gbif.org/species/\(clave)")], em: 0.75))
                    .foregroundStyle(p.texto2)
            }
        }
    }

    // MARK: Introducción

    @ViewBuilder
    func seccionIntroduccion(_ e: Especie, _ f: Ficha) -> some View {
        if f.introduccion != nil || f.primerRegistro != nil {
            Seccion("Especie introducida") {
                if let d = f.introduccion {
                    let filas: [(String, String?)] = [("Origen", d.origen), ("Cuándo llegó", d.fecha), ("Cómo llegó", d.via),
                                                       ("Cómo se propaga ahora", d.dispersion), ("Islas donde se introdujo", d.islas)]
                    let validas = filas.compactMap { k, v in v.map { (k, $0) } }
                    VStack(spacing: 0) {
                        ForEach(validas.indices, id: \.self) { i in
                            FilaDato(k: validas[i].0, v: validas[i].1)
                            if i < validas.count - 1 { Separador() }
                        }
                    }
                    Text(tema.rico([.texto("\(d.autor ?? "")\(d.ano.map { " (\($0))" } ?? ""). Ficha de "), .cursiva(d.nombre ?? e.nombre),
                                    .texto(" en: "), .enlace("Compendio de fichas de la Base de especies introducidas en Canarias (2008-2011)", d.url),
                                    .texto(". Gobierno de Canarias, 2022\(d.pagina.map { ", pág. \($0)" } ?? "").")], em: 0.75))
                        .foregroundStyle(p.texto2)
                }
                if let r = f.primerRegistro {
                    Text(tema.rico([.negrita("Primer registro en GBIF en Canarias: "), .texto("\(r.ano)\(r.tipo.map { " (\($0))" } ?? "") · "),
                                    .enlace("ver registro", r.url)]))
                    FuenteDato("Es el registro más antiguo publicado en GBIF; la especie pudo llegar antes.")
                }
            }
        }
    }

    // MARK: Hábitat y Centinela

    @ViewBuilder
    func seccionHabitat(_ f: Ficha) -> some View {
        let texto = f.seccion("Hábitat")
        if !f.habitats.isEmpty || texto != nil {
            Seccion("Hábitat") {
                if !f.habitats.isEmpty {
                    Flujo(espacio: 6) {
                        ForEach(f.habitats, id: \.self) { h in Insignia(h, tipo: .nivel("canario")) }
                    }
                }
                if let texto { Parrafo(texto) }
                FuenteDato("Fuente: " + [f.habitats.isEmpty ? nil : "Biota", texto == nil ? nil : "Centinela"].compactMap { $0 }.joined(separator: " · "))
            }
        }
    }

    @ViewBuilder
    func seccionesCentinela(_ f: Ficha) -> some View {
        let otras = (f.centinela?.secciones ?? []).filter { !["Origen", "Distribución mundial", "Distribución en Canarias", "Hábitat"].contains($0.titulo) }
        ForEach(otras.indices, id: \.self) { i in
            Seccion(otras[i].titulo) {
                Parrafo(otras[i].texto)
                FuenteDato("Fuente: Centinela")
            }
        }
    }

    // MARK: Protección

    @ViewBuilder
    func seccionProteccion(_ f: Ficha) -> some View {
        if !f.proteccion.isEmpty || f.uicn != nil || f.art17 != nil || f.art12 != nil || !f.natura2000.isEmpty {
            let fuentes = [f.uicn != nil ? "UICN vía GBIF" : nil, "Biota", f.centinela != nil ? "Centinela" : nil,
                           f.art17 != nil || f.art12 != nil ? "informes a la UE (EEA)" : nil, f.natura2000.isEmpty ? nil : "Natura 2000 (EEA)"].compactMap { $0 }
            Seccion("Amenaza y protección") {
                VStack(spacing: 0) {
                    if let u = f.uicn {
                        FilaProteccion(codigo: u.codigo, colorUICN: u.codigo, k: "UICN · Lista Roja mundial", v: u.categoria,
                                       pie: tema.rico([.texto("Versión 2022-2\(u.nivel == "especie" ? " · evaluada a nivel de especie" : "")"),
                                                       .texto(u.url != nil ? " · " : ""), .enlace(u.url != nil ? "GBIF" : "", u.url)], em: 0.75))
                        Separador()
                    }
                    if let a = f.art17 {
                        let params = a.parametros.map { "\(Cat.parametro[$0.0] ?? $0.0): \($0.1)" }.joined(separator: " · ")
                        FilaProteccion(codigo: Cat.siglaEstado[a.estado] ?? "?", colorUICN: Cat.uicnDeEstado[a.estado], k: "Estado de conservación · \(a.ambito)",
                                       v: conMayuscula(a.estado) + (a.tendencia.map { " · \($0)" } ?? ""),
                                       pie: tema.rico([.texto("Directiva Hábitats, art. 17 · \(a.periodo) · "), .enlace("EEA", a.url)], em: 0.75),
                                       detalleTitulo: params.isEmpty ? nil : "Por parámetros", detalle: params)
                        Separador()
                    }
                    if let a = f.art12 {
                        let tend = [a.tendencia.map { "Tendencia a corto plazo: \($0)" }, a.tendenciaLarga.map { "a largo plazo: \($0)" }].compactMap { $0 }.joined(separator: " · ")
                        FilaProteccion(codigo: "Art. 12", k: "Población \(a.estacion ?? "") · \(a.ambito)",
                                       v: (a.poblacion ?? "Sin cifra") + (a.fechaPoblacion.map { " (\($0))" } ?? ""),
                                       pie: tema.rico([.texto(tend.isEmpty ? "" : tend + "\n"), .texto("Directiva Aves, art. 12 · \(a.periodo) · "), .enlace("EEA", a.url)], em: 0.75))
                        Separador()
                    }
                    ForEach(filasProteccion(f).indices, id: \.self) { i in
                        let x = filasProteccion(f)[i]
                        FilaProteccion(codigo: Cat.sigla(categoria: x.categoria), k: x.catalogo, v: x.categoria,
                                       pie: tema.rico([.texto(x.islas.joined(separator: ", "))], em: 0.75),
                                       detalleTitulo: x.definicion.isEmpty ? nil : "Qué significa", detalle: x.definicion)
                        Separador()
                    }
                    if !f.natura2000.isEmpty {
                        FilaNatura(espacios: f.natura2000)
                    }
                }
                FuenteDato("Fuente: \(fuentes.joined(separator: " · ")). Categoría por isla según cada catálogo.")
            }
        }
    }

    /// Catálogos agrupados por categoría (con las islas en que se aplica)
    func filasProteccion(_ f: Ficha) -> [(catalogo: String, categoria: String, definicion: String, islas: [String])] {
        var out: [(catalogo: String, categoria: String, definicion: String, islas: [String])] = []
        for pr in f.proteccion {
            var porCat: [(String, String, [String])] = []
            for x in pr.islas {
                if let i = porCat.firstIndex(where: { $0.0 == x.categoria }) {
                    porCat[i].2.append(x.isla)
                } else {
                    porCat.append((x.categoria, x.definicion, [x.isla]))
                }
            }
            for c in porCat { out.append((pr.catalogo, c.0, c.1, c.2)) }
        }
        return out
    }

    @ViewBuilder
    func seccionVulnerabilidad(_ f: Ficha) -> some View {
        if let v = f.vulnerabilidad {
            Seccion("Vulnerabilidad al cambio climático") {
                if let c = v.categoria { FilaDato(k: "Categoría", v: c) }
                if let i = v.indice { FilaDato(k: "Índice", v: i) }
                Text(tema.rico([.texto("Fuente: "), .enlace(v.fuente, v.url)], em: 0.75)).foregroundStyle(p.texto2)
            }
        }
    }

    @ViewBuilder
    func seccionEtimologia(_ f: Ficha) -> some View {
        if let t = f.etimologia {
            Seccion("El nombre") {
                Parrafo(t.texto)
                Text(tema.rico([.texto("Fuente: "), .enlace(t.fuente, t.url)], em: 0.75)).foregroundStyle(p.texto2)
            }
        }
    }

    // MARK: Taxonomía y mismo género

    @ViewBuilder
    func seccionTaxonomia(_ f: Ficha) -> some View {
        if !f.taxonomia.isEmpty {
            Seccion("Taxonomía") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(f.taxonomia.indices, id: \.self) { i in
                        let t = f.taxonomia[i]
                        let esSci = ["Género", "Especie", "Subespecie"].contains(t.rango)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.rango.uppercased()).font(tema.f(0.68, .semi)).tracking(0.6).foregroundStyle(p.texto2)
                            Text(t.valor).font(esSci ? tema.f(0.875, .semi, .cientifico, cursiva: true) : tema.f(0.875, .semi))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(tema.esPoke || tema.esCua ? Color.clear : tema.superficie2, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : tema.radioP))
                        .overlay(RoundedRectangle(cornerRadius: tema.esCua ? 0 : tema.radioP)
                            .strokeBorder(tema.esPoke ? p.texto : (tema.esCua ? p.texto2 : .clear), lineWidth: tema.esPoke ? 2 : 1))
                    }
                }
                if f.sinonimos > 0, let u = URL(string: "\(Cat.biota)/especie/\(codigo)#taxonomyTab") {
                    Link(destination: u) {
                        Text("\(miles(f.sinonimos)) sinónimos (sub nómine) en Biota ›").font(tema.f(0.8, .semi)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func seccionGenero(_ e: Especie) -> some View {
        let otros = almacen.mismoGenero(e)
        if !otros.isEmpty {
            Seccion("Mismo género en Canarias", enlace: "Ver \(otros.count + 1)", accion: { nav.explorar(Filtros(), q: e.genero) }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(otros.prefix(24)) { x in
                            Button { nav.abrir(x.codigo) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Miniatura(e: x, ancho: 112, alto: 84, px: 250)
                                    Text(x.nombreComun).font(tema.f(0.78, .semi)).lineLimit(2).multilineTextAlignment(.leading)
                                    NombreCientifico(nombre: x.nombre, conAutor: false, em: 0.7).foregroundStyle(p.texto2).lineLimit(2)
                                }
                                .frame(width: 112, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16 * tema.esp)
                }
                .padding(.horizontal, -16 * tema.esp)
            }
        }
    }

    // MARK: Webs

    func seccionWebs(_ e: Especie, _ f: Ficha) -> some View {
        var l: [(String, String, String, String)] = []
        l.append(("B", "Ficha en Biota", "Banco de Datos de Biodiversidad de Canarias", "\(Cat.biota)/especie/\(e.codigo)"))
        if let c = f.centinela {
            l.append(("C", "Ficha de especie protegida", "Centinela · Gobierno de Canarias", "\(Cat.centinela)/especie/\(e.codigo)"))
            if c.pdf { l.append(("C", "Ficha en PDF", "Centinela", "\(Cat.centinela)/especie/\(e.codigo)/informe")) }
        }
        for en in f.enlaces {
            let u = en.url
            if u.contains("iucnredlist") { l.append(("U", "Lista Roja de la UICN", "iucnredlist.org", u)) }
            else if u.contains("gbif.org") { l.append(("G", "GBIF", "Global Biodiversity Information Facility", u)) }
            else if u.contains("magrama") || u.contains("miteco") || u.contains("mapama") { l.append(("M", "Libros Rojos", "Ministerio para la Transición Ecológica", u)) }
            else if u.contains("eionet") { l.append(("E", "Informe artículo 17 · \(en.titulo)", "Directiva Hábitats · EIONET", u)) }
            else { l.append(("·", en.titulo.isEmpty ? "Enlace" : en.titulo, URL(string: u)?.host ?? u, u)) }
        }
        let orig = f.origen?.codigo.isEmpty == false ? f.origen!.codigo : e.origen
        if ["ISI", "ISP"].contains(orig) {
            l.append(("R", "Especies exóticas invasoras · REDEXOS", "Gobierno de Canarias: cómo avisar de un avistamiento", Cat.redexos))
        }
        let binomio = Cat.binomio(e.nombre).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        l.append(("i", "iNaturalist", "Observaciones ciudadanas", "https://www.inaturalist.org/taxa/search?q=\(binomio)"))
        return VStack(spacing: tema.hueco) {
            Seccion("Webs oficiales") {
                VStack(spacing: 0) {
                    ForEach(l.indices, id: \.self) { i in
                        EnlaceOficial(inicial: l[i].0, titulo: l[i].1, detalle: l[i].2, url: l[i].3)
                        if i < l.count - 1 { Separador() }
                    }
                }
            }
            if let evc = f.evc {
                Seccion("Otras webs") {
                    EnlaceOficial(inicial: "EV", titulo: "Especies Vegetales en Canarias", detalle: "Fotos y ficha · © \(evc.autoria)", url: evc.url)
                }
            }
        }
    }

    // MARK: Avistamientos y fuentes

    @ViewBuilder
    func seccionAvistamientos(_ e: Especie) -> some View {
        if !avs.isEmpty {
            Seccion("Tus avistamientos") {
                VStack(spacing: 0) {
                    ForEach(avs) { a in
                        Button { detalle = a } label: { FilaAvistamiento(a: a, e: nil) }
                            .buttonStyle(.plain)
                        if a.id != avs.last?.id { Separador() }
                    }
                }
            }
        }
    }

    func seccionFuentes(_ f: Ficha) -> some View {
        var filas: [(String, String)] = [("Nombres, taxonomía, endemicidad y origen", "Biota"), ("Presencia por islas y protección", "Biota")]
        if f.centinela != nil { filas.append(("Distribución, hábitat y claves", "Centinela")) }
        if f.uicn != nil { filas.append(("Categoría UICN", "UICN 2022-2 vía GBIF")) }
        if let t = f.tamano { filas.append(("Tamaño", t.fuente)) }
        if let x = f.peso { filas.append(("Peso", x.fuente)) }
        if let x = f.longevidad { filas.append(("Longevidad", x.fuente)) } else if let c = f.ciclo { filas.append(("Ciclo de vida", c.fuente)) }
        if !f.rasgos.isEmpty { filas.append(("Biología", f.rasgos.map(\.fuente).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " · "))) }
        if !f.sonidos.isEmpty { filas.append(("Sonidos", f.sonidos.map(\.fuente).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " · "))) }
        if f.altitud != nil { filas.append(("Altitud", "GBIF · Copernicus GLO-90")) }
        if f.mundo != nil { filas.append(("Distribución mundial", "WCVP (Kew)")) }
        if f.art17 != nil || f.art12 != nil { filas.append(("Estado en la UE", "Informes art. 12 y 17 (EEA)")) }
        if !f.natura2000.isEmpty { filas.append(("Red Natura 2000", "EEA")) }
        if f.introduccion != nil { filas.append(("Introducción", "Compendio de especies introducidas (Gob. de Canarias)")) }
        if f.primerRegistro != nil { filas.append(("Primer registro", "GBIF")) }
        if f.tallaMinima != nil { filas.append(("Talla mínima", "BOE (RD 560/1995)")) }
        if f.etimologia != nil { filas.append(("Etimología", "Wikipedia (es)")) }
        if let v = f.vulnerabilidad { filas.append(("Vulnerabilidad al cambio climático", v.fuente)) }
        filas.append(("Calendario", "iNaturalist"))
        let ff = URLsFotos.fuentes(f)
        filas.append(("Fotos", ff.isEmpty ? "—" : ff))
        return Seccion("De dónde sale cada dato") {
            ForEach(filas.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text(filas[i].0).font(tema.f(0.82))
                    Spacer(minLength: 8)
                    Text(filas[i].1).font(tema.f(0.82, .semi)).multilineTextAlignment(.trailing)
                }
            }
            FuenteDato("Datos descargados el \(f.actualizado).\(f.referencias > 0 ? " Biota cita \(miles(f.referencias)) referencias para este taxón." : "")")
        }
    }
}

// MARK: - Piezas de la ficha

struct Leyenda: View {
    let texto: String
    let relleno: Color
    var borde: Color = .clear
    var discontinuo = false
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(relleno)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(borde, style: StrokeStyle(lineWidth: 1.5, dash: discontinuo ? [3, 2] : [])))
                .frame(width: 12, height: 12)
            Text(texto).font(tema.f(0.75)).foregroundStyle(p.texto2)
        }
    }
}

struct FilaProteccion: View {
    let codigo: String
    var colorUICN: String?
    let k: String
    let v: String
    var pie: AttributedString?
    var detalleTitulo: String?
    var detalle: String?
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @State private var abierto = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(codigo)
                .font(tema.f(0.72, .negrita))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(colorTexto)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(minWidth: 46, minHeight: 28)
                .background(colorFondo, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : 6))
                .overlay(RoundedRectangle(cornerRadius: tema.esCua ? 0 : 6).strokeBorder(colorBorde, lineWidth: tema.esPoke ? 2 : 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(k).font(tema.f(0.75)).foregroundStyle(p.texto2)
                Text(v).font(tema.f(0.9, .semi))
                if let pie, !pie.characters.isEmpty { Text(pie).foregroundStyle(p.texto2) }
                if let detalleTitulo, let detalle {
                    Button { withAnimation(tema.animacion) { abierto.toggle() } } label: {
                        Text(detalleTitulo + (abierto ? " ▴" : " ▾")).font(tema.f(0.75)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                    if abierto { Text(detalle).font(tema.f(0.8)).fixedSize(horizontal: false, vertical: true) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private var uicn: Cat.CategoriaUICN? { colorUICN.flatMap { Cat.categoriaUICN($0) } }
    private var colorFondo: Color {
        if let u = uicn { return Color(hex: u.color) }
        return tema.esPoke || tema.esCua ? .clear : tema.acentoSuave
    }
    private var colorTexto: Color {
        if let u = uicn { return Color(hex: u.texto) }
        return tema.esPoke || tema.esCua ? p.texto : tema.acentoTinta
    }
    private var colorBorde: Color {
        if uicn != nil { return .clear }
        return tema.esPoke ? p.texto : (tema.esCua ? p.texto2 : .clear)
    }
}

struct FilaNatura: View {
    let espacios: [Ficha.EspacioNatura]
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @State private var abierto = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("N2000")
                .font(tema.f(0.72, .negrita))
                .foregroundStyle(tema.esPoke || tema.esCua ? p.texto : tema.acentoTinta)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(minWidth: 46, minHeight: 28)
                .background(tema.esPoke || tema.esCua ? Color.clear : tema.acentoSuave, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : 6))
                .overlay(RoundedRectangle(cornerRadius: tema.esCua ? 0 : 6).strokeBorder(tema.esPoke ? p.texto : (tema.esCua ? p.texto2 : .clear), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text("Red Natura 2000 en Canarias").font(tema.f(0.75)).foregroundStyle(p.texto2)
                Text("En el formulario oficial de \(espacios.count) espacio\(espacios.count > 1 ? "s" : "")").font(tema.f(0.9, .semi))
                Button { withAnimation(tema.animacion) { abierto.toggle() } } label: {
                    Text("Ver los espacios" + (abierto ? " ▴" : " ▾")).font(tema.f(0.75)).foregroundStyle(tema.esPoke ? p.texto : tema.acento)
                }
                .buttonStyle(.plain)
                if abierto {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(espacios, id: \.self) { x in
                            if let u = URL(string: "https://natura2000.eea.europa.eu/Natura2000/SDF.aspx?site=\(x.codigo)") {
                                Link(destination: u) {
                                    Text(tema.rico([.texto("• "), .negrita(x.nombre), .texto(" · \(Cat.tipoSitio[x.tipo] ?? "") · \(x.codigo)")], em: 0.82))
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(p.texto)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}

struct EnlaceOficial: View {
    let inicial: String
    let titulo: String
    let detalle: String
    let url: String
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p

    var body: some View {
        if let u = URL(string: url) {
            Link(destination: u) {
                HStack(spacing: 12) {
                    Text(inicial)
                        .font(tema.f(1, .negrita))
                        .foregroundStyle(tema.esPoke || tema.esCua ? p.texto : tema.acentoTinta)
                        .frame(width: 34, height: 34)
                        .background(tema.esPoke || tema.esCua ? Color.clear : tema.acentoSuave, in: RoundedRectangle(cornerRadius: tema.esCua ? 0 : 10))
                        .overlay(RoundedRectangle(cornerRadius: tema.esCua ? 0 : 10).strokeBorder(tema.esPoke ? p.texto : (tema.esCua ? p.texto2 : .clear), lineWidth: tema.esPoke ? 2 : 1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(titulo).font(tema.f(0.875, .semi)).foregroundStyle(p.texto).multilineTextAlignment(.leading)
                        Text(detalle).font(tema.f(0.75)).foregroundStyle(p.texto2).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Icono("externo", tam: 18).foregroundStyle(p.texto2)
                }
                .padding(.vertical, 9)
            }
        }
    }
}

struct FilaSonido: View {
    let s: Ficha.Sonido
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    private var rep: Reproductor { Reproductor.compartido }

    var body: some View {
        let url = URL(string: s.url)
        let actual = url != nil && rep.actual == url
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    if let url { rep.alternar(url) }
                } label: {
                    Image(systemName: actual && rep.sonando ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tema.esPoke ? Color.white : tema.acentoTxt)
                        .frame(width: 40, height: 40)
                        .background(tema.esPoke ? tema.oscuroPoke : tema.acento, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actual && rep.sonando ? "Pausar" : "Reproducir")
                BarraProgreso(valor: actual ? rep.progreso : 0)
            }
            let tipo = [Cat.tipoSonido(s.tipo), Cat.tipoSonido(s.lugar)].filter { !$0.isEmpty }.joined(separator: " · ")
            Text(tema.rico([.texto((tipo.isEmpty ? "Grabación" : tipo) + (s.canarias ? "" : " (fuera de Canarias)") + " · \(s.autor) · "),
                            .enlace(s.lic, s.licUrl), .texto(" · "), .enlace(s.fuente, s.pagina)], em: 0.8))
                .foregroundStyle(p.texto2)
        }
        .onDisappear { if actual { rep.parar() } }
    }
}
