import Foundation
import AppKit

enum FitMode: String, CaseIterable {
    case fill, fit, stretch
    var label: String {
        switch self {
        case .fill: return "Fill (aspect, crop)"
        case .fit: return "Fit (aspect, letterbox)"
        case .stretch: return "Stretch"
        }
    }
}

/// Per-screen wallpaper assignment.
struct ScreenAssignment: Codable, Equatable {
    enum Kind: String, Codable { case video, web }
    var kind: Kind
    var value: String   // file path or URL string
}

final class Preferences {
    static let shared = Preferences()
    private let d = UserDefaults.standard

    private enum Keys {
        static let lastVideo       = "lastVideoBookmark"
        static let muted           = "muted"
        static let fit             = "fitMode"
        static let brightness      = "brightness"
        static let blurRadius      = "blurRadius"
        static let playbackRate    = "playbackRate"
        static let assignments     = "screenAssignments"  // [screenUUID: ScreenAssignment]
        static let playlistEnabled = "playlistEnabled"
        static let playlistShuffle = "playlistShuffle"
        static let playlistInterval = "playlistIntervalSec"
        static let smartPauseFullscreen = "smartPauseFullscreen"
        static let smartPauseLowPower   = "smartPauseLowPower"
    }

    init() {
        if d.object(forKey: Keys.muted)          == nil { d.set(true, forKey: Keys.muted) }
        if d.object(forKey: Keys.fit)            == nil { d.set(FitMode.fill.rawValue, forKey: Keys.fit) }
        if d.object(forKey: Keys.brightness)     == nil { d.set(1.0, forKey: Keys.brightness) }
        if d.object(forKey: Keys.blurRadius)     == nil { d.set(0.0, forKey: Keys.blurRadius) }
        if d.object(forKey: Keys.playbackRate)   == nil { d.set(1.0, forKey: Keys.playbackRate) }
        if d.object(forKey: Keys.playlistEnabled) == nil { d.set(false, forKey: Keys.playlistEnabled) }
        if d.object(forKey: Keys.playlistShuffle) == nil { d.set(true, forKey: Keys.playlistShuffle) }
        if d.object(forKey: Keys.playlistInterval) == nil { d.set(900, forKey: Keys.playlistInterval) }
        if d.object(forKey: Keys.smartPauseFullscreen) == nil { d.set(true, forKey: Keys.smartPauseFullscreen) }
        if d.object(forKey: Keys.smartPauseLowPower)   == nil { d.set(true, forKey: Keys.smartPauseLowPower) }
    }

    var muted: Bool {
        get { d.bool(forKey: Keys.muted) }
        set { d.set(newValue, forKey: Keys.muted) }
    }

    var fitMode: FitMode {
        get { FitMode(rawValue: d.string(forKey: Keys.fit) ?? "") ?? .fill }
        set { d.set(newValue.rawValue, forKey: Keys.fit) }
    }

    var brightness: Double {
        get { d.double(forKey: Keys.brightness) }
        set { d.set(newValue, forKey: Keys.brightness) }
    }

    var blurRadius: Double {
        get { d.double(forKey: Keys.blurRadius) }
        set { d.set(newValue, forKey: Keys.blurRadius) }
    }

    var playbackRate: Double {
        get { d.double(forKey: Keys.playbackRate) }
        set { d.set(newValue, forKey: Keys.playbackRate) }
    }

    var playlistEnabled: Bool {
        get { d.bool(forKey: Keys.playlistEnabled) }
        set { d.set(newValue, forKey: Keys.playlistEnabled) }
    }
    var playlistShuffle: Bool {
        get { d.bool(forKey: Keys.playlistShuffle) }
        set { d.set(newValue, forKey: Keys.playlistShuffle) }
    }
    var playlistIntervalSec: Int {
        get { d.integer(forKey: Keys.playlistInterval) }
        set { d.set(newValue, forKey: Keys.playlistInterval) }
    }

    var smartPauseFullscreen: Bool {
        get { d.bool(forKey: Keys.smartPauseFullscreen) }
        set { d.set(newValue, forKey: Keys.smartPauseFullscreen) }
    }
    var smartPauseLowPower: Bool {
        get { d.bool(forKey: Keys.smartPauseLowPower) }
        set { d.set(newValue, forKey: Keys.smartPauseLowPower) }
    }

    // MARK: - Last source (fallback / legacy)

    var lastVideoURL: URL? {
        get {
            guard let path = d.string(forKey: Keys.lastVideo), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            if let url = newValue {
                d.set(url.path, forKey: Keys.lastVideo)
            } else {
                d.removeObject(forKey: Keys.lastVideo)
            }
        }
    }

    // MARK: - Per-screen assignments

    private func loadAssignments() -> [String: ScreenAssignment] {
        guard let data = d.data(forKey: Keys.assignments) else { return [:] }
        return (try? JSONDecoder().decode([String: ScreenAssignment].self, from: data)) ?? [:]
    }

    private func saveAssignments(_ map: [String: ScreenAssignment]) {
        if let data = try? JSONEncoder().encode(map) {
            d.set(data, forKey: Keys.assignments)
        }
    }

    func assignment(for screen: NSScreen) -> ScreenAssignment? {
        guard let uuid = ScreenIdentity.uuid(for: screen) else { return nil }
        return loadAssignments()[uuid]
    }

    func setAssignment(_ a: ScreenAssignment?, for screen: NSScreen) {
        guard let uuid = ScreenIdentity.uuid(for: screen) else { return }
        var map = loadAssignments()
        if let a = a { map[uuid] = a } else { map.removeValue(forKey: uuid) }
        saveAssignments(map)
    }

    func clearAllAssignments() { saveAssignments([:]) }

    /// Global (all-screens) source, used when there's no per-screen override.
    var globalSource: WallpaperSource? {
        get {
            if let url = lastVideoURL, FileManager.default.fileExists(atPath: url.path) {
                return .video(url)
            }
            return nil
        }
    }

    func resolveSource(for screen: NSScreen) -> WallpaperSource? {
        if let a = assignment(for: screen) {
            switch a.kind {
            case .video:
                let url = URL(fileURLWithPath: a.value)
                if FileManager.default.fileExists(atPath: url.path) { return .video(url) }
            case .web:
                if let url = URL(string: a.value) { return .web(url) }
            }
        }
        return globalSource
    }
}

/// Stable identifier per physical display across launches.
enum ScreenIdentity {
    static func uuid(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return String(displayID)
        }
        return CFUUIDCreateString(nil, cfUUID) as String
    }

    static func label(for screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName
        return name.isEmpty ? "Display \(index + 1)" : name
    }
}
