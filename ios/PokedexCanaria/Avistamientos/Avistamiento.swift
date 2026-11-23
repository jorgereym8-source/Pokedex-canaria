import Foundation
import SwiftData

/// Un avistamiento guardado en el iPhone (SwiftData)
@Model
final class Avistamiento {
    var uuid: String = UUID().uuidString
    var codigo: String = ""
    var nombre: String = ""
    var comun: String = ""
    var fecha: Date = Date()
    var individuos: Int = 1
    var estados: [String] = []
    var notas: String = ""
    var lat: Double?
    var lon: Double?
    var precision: Double?
    var altitud: Double?
    var isla: String?
    var municipio: String?
    var paraje: String?
    var aproximado: Bool = false
    var ajustadoAMano: Bool = false
    var lugarPendiente: Bool = false
    var tiempoPendiente: Bool = false
    /// Tiempo meteorológico (TiempoAv en JSON)
    var tiempoDatos: Data?
    /// Tu foto (JPEG), guardada aparte de la base de datos
    @Attribute(.externalStorage) var foto: Data?

    init(codigo: String, nombre: String, comun: String, fecha: Date = Date()) {
        self.uuid = UUID().uuidString
        self.codigo = codigo
        self.nombre = nombre
        self.comun = comun
        self.fecha = fecha
    }

    var tiempo: TiempoAv? {
        get { tiempoDatos.flatMap { try? JSONDecoder().decode(TiempoAv.self, from: $0) } }
        set { tiempoDatos = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var tieneLugar: Bool { lat != nil && lon != nil }

    /// «Paraje, Municipio» o la isla
    var lugarCorto: String {
        let l = [paraje, municipio].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return l.isEmpty ? (isla ?? "Sin lugar") : l
    }

    var lugarLargo: String {
        let l = [paraje, municipio, isla].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return l.isEmpty ? "Sin lugar" : l
    }

    /// Formato de la copia de seguridad de la web
    var web: AvistamientoWeb {
        var a = AvistamientoWeb(id: uuid, codigo: codigo, fecha: Fechas.isoTexto(fecha))
        a.nombre = nombre
        a.comun = comun
        a.individuos = individuos
        a.estados = estados
        a.notas = notas
        a.lat = lat
        a.lon = lon
        a.precision = precision
        a.altitud = altitud
        a.isla = isla
        a.municipio = municipio
        a.paraje = paraje
        a.aproximado = aproximado ? true : nil
        a.ajustadoAMano = ajustadoAMano ? true : nil
        a.lugarPendiente = lugarPendiente ? true : nil
        a.tiempoPendiente = tiempoPendiente ? true : nil
        a.tiempo = tiempo
        return a
    }

    /// Crea un avistamiento a partir de una copia de seguridad (nil si la fecha no es válida)
    static func desde(_ w: AvistamientoWeb, especie: Especie?) -> Avistamiento? {
        guard let f = Fechas.iso(w.fecha) else { return nil }
        let a = Avistamiento(codigo: w.codigo, nombre: w.nombre ?? especie?.nombre ?? w.codigo,
                             comun: w.comun ?? especie?.nombreComun ?? w.nombre ?? w.codigo, fecha: f)
        if let id = w.id, !id.isEmpty { a.uuid = id }
        a.individuos = max(1, w.individuos ?? 1)
        a.estados = w.estados ?? []
        a.notas = w.notas ?? ""
        a.lat = w.lat
        a.lon = w.lon
        a.precision = w.precision
        a.altitud = w.altitud
        a.isla = w.isla
        a.municipio = w.municipio
        a.paraje = w.paraje
        a.aproximado = w.aproximado ?? false
        a.ajustadoAMano = w.ajustadoAMano ?? false
        a.lugarPendiente = w.lugarPendiente ?? false
        a.tiempoPendiente = w.tiempoPendiente ?? false
        a.tiempo = w.tiempo
        return a
    }
}

/// Completa el tiempo y el nombre del lugar de los avistamientos guardados sin conexión
@MainActor
enum Pendientes {
    static func completar(_ contexto: ModelContext) async -> Int {
        let d = FetchDescriptor<Avistamiento>(predicate: #Predicate { $0.tiempoPendiente || $0.lugarPendiente })
        guard let lista = try? contexto.fetch(d), !lista.isEmpty else { return 0 }
        var n = 0
        for a in lista {
            guard let lat = a.lat, let lon = a.lon else { continue }
            if a.tiempoPendiente, let t = try? await Servicios.tiempoEn(lat: lat, lon: lon, fecha: a.fecha) {
                a.tiempo = t
                a.tiempoPendiente = false
                n += 1
            }
            if a.lugarPendiente, let l = try? await Servicios.nombreLugar(lat: lat, lon: lon) {
                a.municipio = l.municipio
                a.paraje = l.paraje
                a.lugarPendiente = false
                if a.altitud == nil { a.altitud = try? await Servicios.altitud(lat: lat, lon: lon) }
                n += 1
            }
        }
        try? contexto.save()
        return n
    }
}
