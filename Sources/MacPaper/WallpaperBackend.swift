import AppKit
import AVFoundation
import WebKit

/// Describes what to render as a wallpaper.
enum WallpaperSource: Equatable {
    case video(URL)
    case web(URL)

    var displayName: String {
        switch self {
        case .video(let u): return u.lastPathComponent
        case .web(let u):   return u.host ?? u.absoluteString
        }
    }

    var isFile: Bool {
        if case .video = self { return true } else { return false }
    }

    static func infer(from url: URL) -> WallpaperSource {
        if url.isFileURL { return .video(url) }
        if url.scheme == "http" || url.scheme == "https" { return .web(url) }
        return .video(url)
    }
}
