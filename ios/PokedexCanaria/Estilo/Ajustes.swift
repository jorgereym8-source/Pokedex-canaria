import SwiftUI
import Observation

/// Ajustes de la app, guardados en el iPhone (UserDefaults) con el mismo formato que la web
@MainActor
@Observable
final class Ajustes {
    private static let clave = "pokedex-canaria:ajustes"

    private var guardados: DatosAjustes

    /// Los ajustes; cada cambio se guarda al momento
    var d: DatosAjustes {
        get { guardados }
        set {
            guardados = newValue
            guardar()
        }
    }

    init() {
        if let datos = UserDefaults.standard.data(forKey: Ajustes.clave),
           let g = try? JSONDecoder().decode(DatosAjustes.self, from: datos) {
            guardados = g
        } else {
            guardados = DatosAjustes()
        }
    }

    private func guardar() {
        if let datos = try? JSONEncoder().encode(guardados) {
            UserDefaults.standard.set(datos, forKey: Ajustes.clave)
        }
    }

    func valor(_ id: String) -> String { d.valor(id) }

    /// Orden por defecto de Explorar
    var ordenPorDefecto: Orden { Orden.desde(ajuste: d.numeracion) }
}

/// Navegación entre pestañas y estado de Explorar (para que Inicio, el mapa o una ficha puedan abrir Explorar con filtros)
@MainActor
@Observable
final class Navegacion {
    enum Pestana: String, CaseIterable, Identifiable {
        case inicio, explorar, mapa, vistas, ajustes
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .inicio: return "Inicio"
            case .explorar: return "Explorar"
            case .mapa: return "Mapa"
            case .vistas: return "Vistas"
            case .ajustes: return "Ajustes"
            }
        }
        var icono: String { rawValue }
    }

    var pestana: Pestana = .inicio
    var visitadas: Set<Pestana> = [.inicio]
    var rutaInicio: [Ruta] = []
    var rutaExplorar: [Ruta] = []
    var rutaMapa: [Ruta] = []
    var rutaVistas: [Ruta] = []
    var rutaAjustes: [Ruta] = []

    // Estado de Explorar
    var q = ""
    var filtros = Filtros()
    var orden: Orden?
    /// Cambia cada vez que se abre Explorar desde fuera (para volver arriba del todo)
    var versionExplorar = 0

    /// Aviso breve en la parte de abajo
    var aviso: String?

    func ir(_ p: Pestana) {
        if pestana == p {
            // Tocar la pestaña activa vuelve al principio
            switch p {
            case .inicio: rutaInicio = []
            case .explorar: rutaExplorar = []
            case .mapa: rutaMapa = []
            case .vistas: rutaVistas = []
            case .ajustes: rutaAjustes = []
            }
        }
        pestana = p
        visitadas.insert(p)
    }

    func explorar(_ f: Filtros = Filtros(), q: String = "") {
        filtros = f
        self.q = q
        rutaExplorar = []
        versionExplorar += 1
        pestana = .explorar
        visitadas.insert(.explorar)
    }

    /// Abre una ficha en la pestaña actual
    func abrir(_ codigo: String) {
        switch pestana {
        case .inicio: rutaInicio.append(.especie(codigo))
        case .explorar: rutaExplorar.append(.especie(codigo))
        case .mapa: rutaMapa.append(.especie(codigo))
        case .vistas: rutaVistas.append(.especie(codigo))
        case .ajustes: rutaAjustes.append(.especie(codigo))
        }
    }

    func avisar(_ t: String) {
        aviso = t
        let actual = t
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if self.aviso == actual { self.aviso = nil }
        }
    }
}

enum Ruta: Hashable {
    case especie(String)
}
