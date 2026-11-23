import SwiftUI
import SwiftData

struct InicioView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(Ajustes.self) private var ajustes
    @Environment(Navegacion.self) private var nav
    @Environment(\.tema) private var tema
    @Environment(\.paleta) private var p
    @Query private var avistamientos: [Avistamiento]
    @State private var busqueda = ""

    var body: some View {
        let vistas = Set(avistamientos.map(\.codigo))
        ScrollView {
            VStack(alignment: .leading, spacing: tema.hueco) {
                if tema.esPoke { DecoracionPokedex() }
                cabecera
                buscador
                if let dia = almacen.especieDelDia { especieDelDia(dia) }
                tuPokedex(vistas)
                ForEach(Cat.bloques.indices, id: \.self) { i in bloque(i) }
                porIsla(vistas)
                atajos
                if let m = almacen.meta {
                    Text("Datos de Biota y Centinela · actualizados el \(m.fecha.map(Fechas.corta) ?? m.actualizado)")
                        .font(tema.f(0.8))
                        .foregroundStyle(p.texto2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, tema.margen)
            .padding(.top, 12 + 8 * tema.esp)
            .padding(.bottom, 24)
        }
        .pantalla()
    }

    private var cabecera: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 12) {
                Image("Logo").resizable().interpolation(.high).frame(width: 60, height: 60)
                TituloPantalla(texto: "Flora y fauna\nde Canarias", sobre: "Pokédex Canaria")
            }
            Spacer(minLength: 0)
            BotonIcono(icono: "ajustes", etiqueta: "Ajustes") { nav.ir(.ajustes) }
        }
    }

    private var buscador: some View {
        HStack(spacing: 10) {
            Icono("buscar", tam: 20)
            TextField("Nombre científico o común", text: $busqueda)
                .font(tema.esCua ? tema.f(1.4, .medio, .mano) : .system(size: 16))
                .foregroundStyle(tema.esCua ? tema.acento : tema.texto)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    nav.explorar(Filtros(), q: busqueda)
                    busqueda = ""
                }
        }
        .foregroundStyle(tema.esPoke ? tema.texto2 : p.texto2)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .modifier(EstiloBuscador())
    }

    private func especieDelDia(_ e: Especie) -> some View {
        let foto = URLsFotos.principal(e, biota: ajustes.d.fotosBiota, libres: ajustes.d.fotosLibres, ancho: 960)
        return Button { nav.abrir(e.codigo) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Rectangle().fill(tema.esPoke || tema.esCua ? Color.clear : tema.acentoSuave)
                    Icono(Cat.icono(grupo: e.grupo), tam: 48).foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
                    if let foto {
                        ImagenRemota(url: foto.url, maxPx: 1200).frame(height: 170).clipped()
                    }
                }
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("Especie del día")
                        .font(tema.f(0.75, .semi))
                        .foregroundStyle(tema.esPoke ? tema.texto : tema.acentoTinta)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(tema.esPoke ? tema.fondo : tema.superficie, in: Capsule())
                        .padding(12)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let foto {
                        Text(foto.credito).font(tema.f(0.65)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(numeroPokedex(e.numero)) · \(e.familia.isEmpty ? e.grupo : e.familia)").font(tema.f(0.75, .semi)).foregroundStyle(tema.texto2)
                    Text(tema.esPoke ? e.nombreComun.uppercased() : e.nombreComun)
                        .font(tema.esPoke ? tema.f(1.3, .normal, .lcd) : tema.f(1.3, .negrita))
                    NombreCientifico(nombre: e.nombre, autor: e.autor, conAutor: ajustes.d.autoria)
                    InsigniasEspecie(e: e, pequena: false).padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tarjeta()
            .padding(tema.esCua ? 5 : 0)
            .overlay {
                if tema.esCua { Rectangle().strokeBorder(tema.texto, lineWidth: 1) }
            }
        }
        .buttonStyle(.plain)
    }

    private func tuPokedex(_ vistas: Set<String>) -> some View {
        let total = almacen.indice.count
        let n = almacen.indice.reduce(0) { $0 + (vistas.contains($1.codigo) ? 1 : 0) }
        return VStack(alignment: .leading, spacing: 10 * tema.esp) {
            TituloSeccion("Tu Pokédex", enlace: "Avistamientos") { nav.ir(.vistas) }
            Text(atribuido(n, total)).font(tema.f(0.8)).foregroundStyle(tema.texto2)
            BarraProgreso(valor: total > 0 ? max(n > 0 ? 0.01 : 0, Double(n) / Double(total)) : 0)
        }
        .padding(16 * tema.esp)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    private func atribuido(_ n: Int, _ total: Int) -> AttributedString {
        var a = AttributedString("Has visto ")
        var b = AttributedString(miles(n))
        b.font = tema.f(0.8, .negrita)
        let c = AttributedString(" de \(miles(total)) especies y subespecies")
        a += b
        a += c
        return a
    }

    private func bloque(_ i: Int) -> some View {
        let (titulo, gs0) = Cat.bloques[i]
        let gs = gs0.filter { (almacen.cuentaGrupo[$0] ?? 0) > 0 }
        let total = gs.reduce(0) { $0 + (almacen.cuentaGrupo[$1] ?? 0) }
        let columnas = Array(repeating: GridItem(.flexible(), spacing: 10 * tema.esp), count: tema.esCua ? 2 : 3)
        return Group {
            if !gs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TituloSeccion(titulo, enlace: i == 0 ? "Ver todo" : "Ver \(miles(total))") {
                        var f = Filtros()
                        if i > 0 { f.g = gs }
                        nav.explorar(f)
                    }
                    LazyVGrid(columns: columnas, spacing: tema.esCua ? 0 : 10 * tema.esp) {
                        ForEach(gs, id: \.self) { g in
                            Button {
                                var f = Filtros()
                                f.g = [g]
                                nav.explorar(f)
                            } label: {
                                TileGrupo(grupo: g, cuenta: almacen.cuentaGrupo[g] ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func porIsla(_ vistas: Set<String>) -> some View {
        let prog = Indice.progresoIslas(almacen.indice, vistas: vistas)
        let columnas = Array(repeating: GridItem(.flexible(), spacing: 10 * tema.esp), count: 2)
        return VStack(alignment: .leading, spacing: 8) {
            TituloSeccion("Pokédex por isla")
            LazyVGrid(columns: columnas, spacing: 10 * tema.esp) {
                ForEach(Cat.islasOrden, id: \.self) { k in
                    let pr = prog[k] ?? (total: 0, vistas: 0)
                    Button {
                        var f = Filtros()
                        f.i = [k]
                        nav.explorar(f)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Cat.nombreIsla[k] ?? k).font(tema.f(0.9, .semi)).lineLimit(1)
                            Text(progresoTexto(pr.vistas, pr.total)).font(tema.f(0.72)).foregroundStyle(tema.texto2)
                            BarraProgreso(valor: pr.total > 0 ? max(pr.vistas > 0 ? 0.02 : 0, Double(pr.vistas) / Double(pr.total)) : 0)
                                .padding(.top, 2)
                        }
                        .padding(12 * tema.esp)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tarjeta(radio: tema.radio * 0.85)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func progresoTexto(_ v: Int, _ t: Int) -> AttributedString {
        var a = AttributedString(miles(v))
        a.font = tema.f(0.72, .negrita)
        return a + AttributedString(" de \(miles(t)) vistas")
    }

    private var atajos: some View {
        let amenazadas = almacen.indice.reduce(0) { $0 + ($1.esAmenazada ? 1 : 0) }
        var am = Filtros(); am.am = true
        var ins = Filtros(); ins.nv = ["insular"]
        var end = Filtros(); end.nv = ["insular", "canario"]
        var inv = Filtros(); inv.inv = true
        var pr = Filtros(); pr.pr = true
        let filas: [(String, String, String, Filtros)] = [
            ("alerta", "Amenazadas", "\(miles(amenazadas)) en peligro de extinción o vulnerables", am),
            ("pin", "Exclusivas de una isla", "Endemismos insulares", ins),
            ("hoja", "Endemismos canarios", "Solo viven en Canarias", end),
            ("escudo", "Exóticas invasoras", "Con enlace a REDEXOS", inv),
            ("flor", "Protegidas", "Con ficha en Centinela", pr),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            TituloSeccion("Atajos")
            VStack(spacing: 0) {
                ForEach(filas.indices, id: \.self) { i in
                    let f = filas[i]
                    Button { nav.explorar(f.3) } label: {
                        HStack(spacing: 12) {
                            Icono(f.0, tam: 22).foregroundStyle(tema.esPoke ? tema.texto : tema.acento)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.1).font(tema.f(1, .semi))
                                Text(f.2).font(tema.f(0.82)).foregroundStyle(tema.texto2).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Icono("flecha", tam: 18).foregroundStyle(tema.texto2)
                        }
                        .padding(.vertical, 10 * tema.esp)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < filas.count - 1 { Separador() }
                }
            }
            .tarjeta()
        }
    }
}

/// Casilla de un grupo en Inicio
struct TileGrupo: View {
    let grupo: String
    let cuenta: Int
    @Environment(\.tema) private var tema

    var body: some View {
        switch tema.estilo {
        case .cua:
            HStack(spacing: 10) {
                Icono(Cat.icono(grupo: grupo), tam: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(grupo).font(tema.f(1.05)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(miles(cuenta)).font(tema.f(0.72)).foregroundStyle(tema.texto2)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .overlay(alignment: .bottom) {
                Rectangle().stroke(tema.texto2, style: StrokeStyle(lineWidth: 1, dash: [1, 2])).frame(height: 1)
            }
            .contentShape(Rectangle())
        case .poke:
            VStack(alignment: .leading, spacing: 8) {
                Icono(Cat.icono(grupo: grupo), tam: 20)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.18), in: Circle())
                Text(grupo).font(tema.f(0.82, .semi)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(miles(cuenta)).font(tema.f(0.72)).foregroundStyle(Color.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(12 * tema.esp)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(tema.tecla, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 3)
        case .nat:
            VStack(alignment: .leading, spacing: 8) {
                Icono(Cat.icono(grupo: grupo), tam: 20)
                    .foregroundStyle(tema.acento)
                    .frame(width: 36, height: 36)
                    .background(tema.acentoSuave, in: Circle())
                Text(grupo).font(tema.f(0.82, .semi)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(miles(cuenta)).font(tema.f(0.72)).foregroundStyle(tema.texto2)
            }
            .foregroundStyle(tema.texto)
            .padding(12 * tema.esp)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(tema.superficie, in: RoundedRectangle(cornerRadius: tema.radio * 0.85, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: tema.radio * 0.85, style: .continuous).strokeBorder(tema.borde, lineWidth: 1))
        }
    }
}

/// Caja del buscador según el estilo
struct EstiloBuscador: ViewModifier {
    @Environment(\.tema) private var tema

    func body(content: Content) -> some View {
        Group {
            switch tema.estilo {
            case .cua:
                content
                    .padding(.horizontal, -12)
                    .overlay(alignment: .bottom) { Rectangle().fill(tema.texto).frame(height: 1) }
            case .poke:
                content.tarjeta()
            case .nat:
                content.tarjeta(radio: tema.radio * 0.75)
            }
        }
    }
}
