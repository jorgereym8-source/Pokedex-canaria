import SwiftUI
import UIKit
import ImageIO

/// Descarga y guarda las fotos (Biota, Commons, iNaturalist) para verlas también sin conexión
actor CacheImagenes {
    static let compartida = CacheImagenes()

    private let memoria = NSCache<NSString, UIImage>()
    private var enCurso: [String: Task<UIImage?, Never>] = [:]
    private let carpeta: URL
    private let sesion: URLSession
    private var limpiada = false
    private static let maxArchivos = 1500

    init() {
        let c = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        carpeta = c.appendingPathComponent("imagenes", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        memoria.totalCostLimit = 120 * 1024 * 1024
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = 25
        conf.httpAdditionalHeaders = ["User-Agent": "PokedexCanaria/1.0 (app personal para iPhone)"]
        conf.urlCache = nil
        sesion = URLSession(configuration: conf)
    }

    private static func nombre(_ url: URL) -> String {
        // FNV-1a de 64 bits
        var h: UInt64 = 0xcbf29ce484222325
        for b in url.absoluteString.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return String(h, radix: 16)
    }

    func imagen(_ url: URL, maxPx: CGFloat) async -> UIImage? {
        let clave = "\(url.absoluteString)#\(Int(maxPx))" as NSString
        if let i = memoria.object(forKey: clave) { return i }
        let k = clave as String
        if let t = enCurso[k] { return await t.value }
        let archivo = carpeta.appendingPathComponent(CacheImagenes.nombre(url))
        let s = sesion
        let t = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            var datos = try? Data(contentsOf: archivo)
            if datos == nil {
                guard let res = try? await s.data(from: url) else { return nil }
                let (d, r) = res
                guard let http = r as? HTTPURLResponse, (200..<300).contains(http.statusCode), !d.isEmpty else { return nil }
                try? d.write(to: archivo, options: .atomic)
                datos = d
            }
            guard let d = datos else { return nil }
            return CacheImagenes.reducir(d, maxPx: maxPx)
        }
        enCurso[k] = t
        let img = await t.value
        enCurso[k] = nil
        if let img {
            memoria.setObject(img, forKey: clave, cost: Int(img.size.width * img.size.height * img.scale * img.scale * 4))
        }
        if !limpiada {
            limpiada = true
            Task.detached(priority: .background) { [carpeta] in CacheImagenes.limpiar(carpeta) }
        }
        return img
    }

    /// Reduce la foto al tamaño en que se va a ver (ahorra memoria)
    nonisolated static func reducir(_ d: Data, maxPx: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(d as CFData, nil) else { return UIImage(data: d) }
        let op: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPx),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, op as CFDictionary) else { return UIImage(data: d) }
        return UIImage(cgImage: cg)
    }

    /// Borra las fotos más antiguas si hay demasiadas
    nonisolated static func limpiar(_ carpeta: URL) {
        let fm = FileManager.default
        guard let l = try? fm.contentsOfDirectory(at: carpeta, includingPropertiesForKeys: [.contentModificationDateKey]), l.count > maxArchivos else { return }
        let ordenada = l.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
        for u in ordenada.prefix(l.count - maxArchivos * 4 / 5) { try? fm.removeItem(at: u) }
    }
}

/// Foto descargada de internet; mientras carga (o si falla) muestra lo que haya debajo
struct ImagenRemota: View {
    let url: URL?
    let maxPx: CGFloat
    let modo: ContentMode
    let alFallar: (() -> Void)?
    @State private var imagen: UIImage?
    @Environment(\.tema) private var tema

    init(url: URL?, maxPx: CGFloat = 1200, modo: ContentMode = .fill, alFallar: (() -> Void)? = nil) {
        self.url = url
        self.maxPx = maxPx
        self.modo = modo
        self.alFallar = alFallar
    }

    var body: some View {
        ZStack {
            if let imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .aspectRatio(contentMode: modo)
                    .transition(.opacity)
            }
        }
        .task(id: url) { @MainActor in
            guard let url else { return }
            let i = await CacheImagenes.compartida.imagen(url, maxPx: maxPx)
            if i == nil { alFallar?() }
            withAnimation(tema.animacion) { imagen = i }
        }
    }
}
