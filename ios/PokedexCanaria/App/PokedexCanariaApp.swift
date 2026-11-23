import SwiftUI
import SwiftData

@main
struct PokedexCanariaApp: App {
    @State private var almacen = Almacen()
    @State private var ajustes = Ajustes()
    @State private var nav = Navegacion()

    init() {
        Fuentes.registrar()
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(almacen)
                .environment(ajustes)
                .environment(nav)
        }
        .modelContainer(for: Avistamiento.self)
    }
}
