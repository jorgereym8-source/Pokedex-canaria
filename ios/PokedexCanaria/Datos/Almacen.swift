import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Datos de especies: índice, fichas y actualizaciones.
///
/// La app lleva dentro una copia de los datos (se empaqueta al compilar desde la carpeta datos/ del repositorio).
/// Cuando GitHub publica datos nuevos (el día 3 de cada mes), la app descarga el índice nuevo y, a partir de ahí,
/// pide cada ficha a GitHub Pages la primera vez que la abres y la guarda; sin conexión usa la copia de la app.
@MainActor
@Observable
final class Almacen {
    enum Estado: Equatable {
        case cargando
        case listo
        case error(String)
    }

    private(set) var estado: Estado = .cargando
    private(set) var indice: [Especie] = []
    private(set) var porCodigo: [String: Especie] = [:]
    private(set) var meta: MetaDatos?
    private(set) var cuentaGrupo: [String: Int] = [:]
    private(set) var habitats: [String] = []
    /// true si se usan datos descargados de GitHub, más nuevos que los de la app
    private(set) var usandoDescargados = false
    /// Mensaje de la última comprobación de datos nuevos
    var mensajeDatos: String?
    private(set) var comprobando = false
    /// Progreso de «Guardar todas las fichas» (hechas, total)
    private(set) var descarga: (hechas: Int, total: Int)?

    @ObservationIgnored private var paquete: PaqueteFichas?
    @ObservationIgnored private var cache: [String: Ficha] = [:]
    @ObservationIgnored private var ordenCache: [String] = []
    @ObservationIgnored private let carpetaApp: URL?
    @ObservationIgnored private let carpetaDescargas: URL
    @ObservationIgnored private let sesion: URLSession

    /// De dónde se descargan los datos nuevos: GitHub Pages y, si falla, el repositorio
    static let fuentesDatos = [URL(string: Cat.web + "datos/")!, URL(string: Cat.repositorio + "datos/")!]
    @ObservationIgnored private var fuenteBuena = 0

    /// Descarga un archivo de datos probando las dos fuentes
    private func descargar(_ ruta: String) async throws -> Data {
        var ultimoError: Error = URLError(.badServerResponse)
        let orden = [fuenteBuena] + Almacen.fuentesDatos.indices.filter { $0 != fuenteBuena }
        for i in orden {
            do {
                let (d, r) = try await sesion.data(from: Almacen.fuentesDatos[i].appendingPathComponent(ruta))
                guard (r as? HTTPURLResponse)?.statusCode == 200, !d.isEmpty else { throw URLError(.badServerResponse) }
                fuenteBuena = i
                return d
            } catch {
                ultimoError = error
            }
        }
        throw ultimoError
    }

    init(carpetaApp: URL? = Bundle.main.url(forResource: "Datos", withExtension: nil), carpetaDescargas: URL? = nil) {
        self.carpetaApp = carpetaApp
        let soporte = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        self.carpetaDescargas = carpetaDescargas ?? soporte.appendingPathComponent("DatosDescargados", isDirectory: true)
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = 20
        conf.requestCachePolicy = .reloadIgnoringLocalCacheData
        sesion = URLSession(configuration: conf)
    }

    // MARK: - Carga

    func cargar() async {
        estado = .cargando
        let metaApp = carpetaApp.flatMap { Almacen.leerMeta($0.appendingPathComponent("meta.json")) }
        let metaDesc = Almacen.leerMeta(carpetaDescargas.appendingPathComponent("meta.json"))
        var origen = carpetaApp
        usandoDescargados = false
        if let md = metaDesc {
            if Almacen.esMasNuevo(md, que: metaApp) && FileManager.default.fileExists(atPath: carpetaDescargas.appendingPathComponent("indice.json").path) {
                origen = carpetaDescargas
                usandoDescargados = true
            } else {
                // La app trae datos iguales o más nuevos: lo descargado ya no hace falta
                try? FileManager.default.removeItem(at: carpetaDescargas)
            }
        }
        guard let carpeta = origen else {
            estado = .error("La app no trae los datos de especies. Vuelve a compilarla en Xcode con la carpeta datos/ del repositorio.")
            return
        }
        if let app = carpetaApp { paquete = PaqueteFichas(carpeta: app) }
        do {
            let url = carpeta.appendingPathComponent("indice.json")
            let lista = try await Task.detached(priority: .userInitiated) { () throws -> [Especie] in
                let d = try Data(contentsOf: url)
                let l = try JSONDecoder().decode([Especie].self, from: d)
                Indice.preparar(l)
                return l
            }.value
            aplicar(lista)
            meta = usandoDescargados ? metaDesc : metaApp
            estado = .listo
        } catch {
            if usandoDescargados {
                // Lo descargado está dañado: se vuelve a los datos de la app
                try? FileManager.default.removeItem(at: carpetaDescargas)
                await cargar()
                return
            }
            estado = .error("No se han podido cargar los datos de especies (\(error.localizedDescription)).")
        }
    }

    private func aplicar(_ lista: [Especie]) {
        indice = lista
        var d: [String: Especie] = [:]
        d.reserveCapacity(lista.count)
        for e in lista { d[e.codigo] = e }
        porCodigo = d
        cuentaGrupo = Indice.cuentaPorGrupo(lista)
        habitats = Indice.habitatsFrecuentes(lista)
        cache = [:]
        ordenCache = []
    }

    nonisolated static func leerMeta(_ url: URL) -> MetaDatos? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MetaDatos.self, from: d)
    }

    nonisolated static func esMasNuevo(_ a: MetaDatos, que b: MetaDatos?) -> Bool {
        guard let b else { return true }
        if let fa = a.fecha, let fb = b.fecha { return fa > fb }
        return a.actualizado > b.actualizado
    }

    // MARK: - Fichas

    enum ErrorFicha: LocalizedError {
        case noDisponible
        var errorDescription: String? { "No se ha podido cargar la ficha. ¿Tienes conexión?" }
    }

    func ficha(_ codigo: String) async throws -> Ficha {
        if let f = cache[codigo] { return f }
        var datos: Data?
        if usandoDescargados {
            let archivo = carpetaDescargas.appendingPathComponent("fichas/\(codigo).json")
            if let d = try? Data(contentsOf: archivo) {
                datos = d
            } else if let d = try? await descargarFicha(codigo) {
                datos = d
            }
        }
        if datos == nil, let p = paquete {
            let c = codigo
            datos = await Task.detached(priority: .userInitiated) { p.ficha(c) }.value
        }
        if datos == nil, let app = carpetaApp {
            // Fichas sueltas (si al compilar no se pudieron empaquetar)
            datos = try? Data(contentsOf: app.appendingPathComponent("fichas/\(codigo).json"))
        }
        if datos == nil, !usandoDescargados {
            // Ficha que no está en la app (no debería pasar): se intenta en la web
            datos = try? await descargarFicha(codigo, guardar: false)
        }
        guard let d = datos else { throw ErrorFicha.noDisponible }
        let f = try await Task.detached(priority: .userInitiated) { Ficha(json: try LectorJSON.leer(d)) }.value
        guardarEnCache(codigo, f)
        return f
    }

    private func guardarEnCache(_ codigo: String, _ f: Ficha) {
        cache[codigo] = f
        ordenCache.append(codigo)
        if ordenCache.count > 120 {
            let fuera = ordenCache.removeFirst()
            cache[fuera] = nil
        }
    }

    private func descargarFicha(_ codigo: String, guardar: Bool = true) async throws -> Data {
        let d = try await descargar("fichas/\(codigo).json")
        guard d.first == UInt8(ascii: "{") else { throw ErrorFicha.noDisponible }
        if guardar {
            let carpeta = carpetaDescargas.appendingPathComponent("fichas", isDirectory: true)
            try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            try? d.write(to: carpeta.appendingPathComponent("\(codigo).json"), options: .atomic)
        }
        return d
    }

    // MARK: - Actualizaciones

    private static let claveUltima = "pokedex-canaria:ultima-comprobacion"

    /// Comprueba si GitHub tiene datos más nuevos (como mucho una vez al día, salvo que se pida a mano)
    func comprobarDatosNuevos(aMano: Bool = false) async {
        guard estado == .listo, !comprobando else { return }
        let ahora = Date().timeIntervalSince1970
        if !aMano, ahora - UserDefaults.standard.double(forKey: Almacen.claveUltima) < 20 * 3600 { return }
        comprobando = true
        defer { comprobando = false }
        do {
            let dm = try await descargar("meta.json")
            let remota = try JSONDecoder().decode(MetaDatos.self, from: dm)
            UserDefaults.standard.set(ahora, forKey: Almacen.claveUltima)
            guard Almacen.esMasNuevo(remota, que: meta) else {
                if aMano { mensajeDatos = "Ya tienes los datos más recientes" }
                return
            }
            mensajeDatos = "Descargando datos nuevos…"
            let di = try await descargar("indice.json")
            let lista = try await Task.detached(priority: .utility) { () throws -> [Especie] in
                let l = try JSONDecoder().decode([Especie].self, from: di)
                Indice.preparar(l)
                return l
            }.value
            guard lista.count > 100 else { throw URLError(.cannotParseResponse) }
            // Guardar: las fichas descargadas antes eran de la versión anterior
            let fm = FileManager.default
            try? fm.removeItem(at: carpetaDescargas)
            try fm.createDirectory(at: carpetaDescargas.appendingPathComponent("fichas", isDirectory: true), withIntermediateDirectories: true)
            try di.write(to: carpetaDescargas.appendingPathComponent("indice.json"), options: .atomic)
            try dm.write(to: carpetaDescargas.appendingPathComponent("meta.json"), options: .atomic)
            aplicar(lista)
            meta = remota
            usandoDescargados = true
            mensajeDatos = "Datos actualizados: \(miles(lista.count)) especies (\(remota.fecha.map(Fechas.corta) ?? remota.actualizado))"
        } catch {
            if aMano { mensajeDatos = "No se ha podido comprobar si hay datos nuevos (¿sin conexión?)" }
        }
    }

    /// Descarga todas las fichas de la versión nueva para usarlas sin conexión
    func descargarTodas() async {
        guard descarga == nil else { return }
        guard usandoDescargados else {
            mensajeDatos = "Todas las fichas ya están dentro de la app"
            return
        }
        let carpeta = carpetaDescargas.appendingPathComponent("fichas", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let fm = FileManager.default
        let pendientes = indice.map(\.codigo).filter { !fm.fileExists(atPath: carpeta.appendingPathComponent("\($0).json").path) }
        let total = indice.count
        var hechas = total - pendientes.count
        var fallos = 0
        descarga = (hechas, total)
        var i = 0
        let lote = 8
        while i < pendientes.count {
            let trozo = Array(pendientes[i..<min(i + lote, pendientes.count)])
            let resultados = await withTaskGroup(of: Bool.self) { grupo -> [Bool] in
                for c in trozo {
                    grupo.addTask { [weak self] in
                        guard let self else { return false }
                        return (try? await self.descargarFicha(c)) != nil
                    }
                }
                var r: [Bool] = []
                for await x in grupo { r.append(x) }
                return r
            }
            hechas += resultados.filter { $0 }.count
            fallos += resultados.filter { !$0 }.count
            descarga = (hechas, total)
            i += lote
            if fallos > 200 { break }
        }
        descarga = nil
        mensajeDatos = fallos == 0 ? "Todas las fichas guardadas en el iPhone" : "Guardadas \(miles(hechas)) de \(miles(total)) fichas; vuelve a intentarlo con conexión"
    }

    // MARK: - Consultas

    func especie(_ codigo: String) -> Especie? { porCodigo[codigo] }

    func mismoGenero(_ e: Especie) -> [Especie] { Indice.mismoGenero(e, en: indice) }

    var especieDelDia: Especie? { Indice.especieDelDia(indice) }
}
