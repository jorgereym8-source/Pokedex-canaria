import Foundation
import CoreLocation

/// Pide la posición GPS una vez
final class Ubicador: NSObject, CLLocationManagerDelegate {
    enum Fallo: LocalizedError {
        case denegado, noDisponible
        var errorDescription: String? {
            switch self {
            case .denegado: return "Permiso de ubicación denegado (actívalo en Ajustes › Pokédex › Ubicación)"
            case .noDisponible: return "No se pudo obtener la ubicación"
            }
        }
    }

    private let gestor = CLLocationManager()
    private var continuacion: CheckedContinuation<CLLocation, Error>?
    private var pedida = false

    override init() {
        super.init()
        gestor.delegate = self
        gestor.desiredAccuracy = kCLLocationAccuracyBest
    }

    @MainActor
    func ubicar() async throws -> CLLocation {
        if continuacion != nil { throw Fallo.noDisponible }
        return try await withCheckedThrowingContinuation { c in
            continuacion = c
            pedida = false
            switch gestor.authorizationStatus {
            case .notDetermined:
                gestor.requestWhenInUseAuthorization()
            case .denied, .restricted:
                terminar(.failure(Fallo.denegado))
            default:
                pedir()
            }
            // Si en 25 s no hay respuesta, se da por perdida
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                self?.terminar(.failure(Fallo.noDisponible))
            }
        }
    }

    private func pedir() {
        guard !pedida else { return }
        pedida = true
        gestor.requestLocation()
    }

    private func terminar(_ r: Result<CLLocation, Error>) {
        guard let c = continuacion else { return }
        continuacion = nil
        c.resume(with: r)
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        guard continuacion != nil else { return }
        switch m.authorizationStatus {
        case .notDetermined: break
        case .denied, .restricted: terminar(.failure(Fallo.denegado))
        default: pedir()
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let l = locs.last { terminar(.success(l)) }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        if let e = error as? CLError, e.code == .denied {
            terminar(.failure(Fallo.denegado))
        } else {
            terminar(.failure(Fallo.noDisponible))
        }
    }
}
