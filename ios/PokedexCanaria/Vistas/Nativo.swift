import SwiftUI
import UIKit
import MapKit
import AVFoundation
import Observation

// MARK: - Cámara

/// Cámara del iPhone para hacer la foto del avistamiento
struct Camara: UIViewControllerRepresentable {
    let alTerminar: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(self) }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let padre: Camara
        init(_ p: Camara) { padre = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            padre.alTerminar(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.alTerminar(nil)
        }
    }
}

enum Fotos {
    /// Reduce la foto a 1600 px como mucho y la guarda en JPEG
    static func reducir(_ img: UIImage, max lado: CGFloat = 1600) -> Data? {
        let k = min(1, lado / max(img.size.width, img.size.height))
        let tam = CGSize(width: (img.size.width * k).rounded(), height: (img.size.height * k).rounded())
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        let r = UIGraphicsImageRenderer(size: tam, format: formato)
        let reducida = r.image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }
        return reducida.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Sonidos

/// Reproduce los cantos y sonidos de las fichas (uno cada vez)
@MainActor
@Observable
final class Reproductor {
    static let compartido = Reproductor()

    private(set) var actual: URL?
    private(set) var sonando = false
    private(set) var progreso: Double = 0
    @ObservationIgnored private var jugador: AVPlayer?
    @ObservationIgnored private var observador: Any?
    @ObservationIgnored private var fin: NSObjectProtocol?

    func alternar(_ url: URL) {
        if actual == url, let j = jugador {
            if sonando { j.pause(); sonando = false } else { j.play(); sonando = true }
            return
        }
        parar()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let j = AVPlayer(playerItem: item)
        jugador = j
        actual = url
        progreso = 0
        observador = j.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let d = j.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
            let valor = t.seconds / d
            Task { @MainActor in self?.progreso = valor }
        }
        fin = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.sonando = false
                self?.progreso = 0
                self?.jugador?.seek(to: .zero)
            }
        }
        j.play()
        sonando = true
    }

    func parar() {
        jugador?.pause()
        if let o = observador { jugador?.removeTimeObserver(o) }
        if let f = fin { NotificationCenter.default.removeObserver(f) }
        observador = nil
        fin = nil
        jugador = nil
        actual = nil
        sonando = false
        progreso = 0
    }
}

// MARK: - Mapa de registros de GBIF

/// Mapa de Apple con la densidad de registros de GBIF encima
struct MapaGBIF: UIViewRepresentable {
    let clave: Int
    let amenazada: Bool

    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView()
        m.delegate = context.coordinator
        m.pointOfInterestFilter = .excludingAll
        m.showsCompass = false
        m.isRotateEnabled = false
        m.isPitchEnabled = false
        let bin = amenazada ? "bin=square&squareSize=128" : "bin=hex&hexPerTile=40"
        let plantilla = "https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?taxonKey=\(clave)&\(bin)&style=classic.poly"
        let capa = MKTileOverlay(urlTemplate: plantilla)
        capa.canReplaceMapContent = false
        capa.maximumZ = amenazada ? 8 : 12
        m.addOverlay(capa, level: .aboveRoads)
        m.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 28.3, longitude: -15.8),
                                       span: MKCoordinateSpan(latitudeDelta: 2.4, longitudeDelta: 5.6)), animated: false)
        return m
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador() }

    final class Coordinador: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let t = overlay as? MKTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: t)
                r.alpha = 0.85
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Volver deslizando

/// Mantiene el gesto de deslizar desde el borde para volver aunque la barra de navegación esté oculta
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
