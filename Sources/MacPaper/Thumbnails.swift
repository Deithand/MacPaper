import AppKit
import AVFoundation
import CryptoKit

/// Generates and caches small video thumbnails for menu items.
enum Thumbnails {
    private static let size = NSSize(width: 64, height: 36)

    private static let cacheDir: URL = {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("MacPaper/thumbs", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Sync, fast path: returns cached thumbnail if available; otherwise generates now (cheap frame).
    static func thumbnail(for url: URL) -> NSImage? {
        let key = cacheKey(for: url)
        let cached = cacheDir.appendingPathComponent("\(key).png")
        if let img = NSImage(contentsOf: cached) { return img }

        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        guard let cg = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }

        let image = NSImage(cgImage: cg, size: size)
        image.size = size
        if let rep = image.representations.first as? NSBitmapImageRep,
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: cached)
        } else {
            // re-encode via PNG
            if let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: cached)
            }
        }
        return image
    }

    private static func cacheKey(for url: URL) -> String {
        let fm = FileManager.default
        var seed = url.path
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           let size = attrs[.size] as? NSNumber {
            seed += "|\(mod.timeIntervalSince1970)|\(size.intValue)"
        }
        let digest = Insecure.MD5.hash(data: Data(seed.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
