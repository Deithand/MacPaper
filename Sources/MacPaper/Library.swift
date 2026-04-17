import Foundation

/// Simple file-based library at ~/Movies/MacPaper.
final class Library {
    static let shared = Library()

    let folder: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("MacPaper", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "webm", "mpg", "mpeg"
    ]

    func items() -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return [] }
        return entries
            .filter { Library.videoExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func `import`(urls: [URL]) {
        let fm = FileManager.default
        for src in urls {
            let dst = folder.appendingPathComponent(src.lastPathComponent)
            if fm.fileExists(atPath: dst.path) { continue }
            try? fm.copyItem(at: src, to: dst)
        }
    }
}
