import AppKit

/// Manages per-screen wallpaper windows.
final class WallpaperController {
    /// Exposed for SwiftUI / other UI surfaces that need to drive the controller.
    static weak var shared: WallpaperController?

    /// Keyed by stable screen UUID.
    private(set) var windows: [String: WallpaperWindow] = [:]
    var onStateChange: (() -> Void)?

    var isRunning: Bool { !windows.isEmpty }

    init() {
        Self.shared = self
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)

        SmartPause.shared.onChange = { [weak self] pause in
            guard let self = self else { return }
            self.windows.values.forEach { pause ? $0.pausePlayback() : $0.resumePlayback() }
        }
        SmartPause.shared.start()

        Playlist.shared.onAdvance = { [weak self] url in
            self?.setGlobal(source: .video(url))
        }
    }

    // MARK: - Global (all screens) apply

    func setGlobal(source: WallpaperSource) {
        switch source {
        case .video(let url):
            // For videos, persist as the fallback source and let existing
            // per-screen overrides win. This matches the "global is a fallback"
            // contract.
            Preferences.shared.lastVideoURL = url
        case .web(let url):
            // There is no persistent "global web" slot; emulate one by
            // assigning the same web source to every screen. Clearing the
            // video fallback avoids any stale video resurfacing on screens
            // that later lose their assignment.
            Preferences.shared.lastVideoURL = nil
            Preferences.shared.clearAllAssignments()
            for screen in NSScreen.screens {
                Preferences.shared.setAssignment(
                    ScreenAssignment(kind: .web, value: url.absoluteString),
                    for: screen
                )
            }
        }
        rebuildAll()
        onStateChange?()
    }

    func setPerScreen(source: WallpaperSource, screen: NSScreen) {
        let a: ScreenAssignment
        switch source {
        case .video(let u): a = ScreenAssignment(kind: .video, value: u.path)
        case .web(let u):   a = ScreenAssignment(kind: .web, value: u.absoluteString)
        }
        Preferences.shared.setAssignment(a, for: screen)
        rebuildAll()
        onStateChange?()
    }

    func clearPerScreen(_ screen: NSScreen) {
        Preferences.shared.setAssignment(nil, for: screen)
        rebuildAll()
        onStateChange?()
    }

    func start() {
        rebuildAll()
        onStateChange?()
    }

    func stop() {
        for (_, w) in windows { w.tearDown() }
        windows.removeAll()
        onStateChange?()
    }

    func applyAudio() { windows.values.forEach { $0.applyAudio() } }
    func applyFit()   { windows.values.forEach { $0.applyFit() } }
    func applyOverlay() { windows.values.forEach { $0.applyOverlay() } }
    func applyLicense() { windows.values.forEach { $0.updateWatermarkVisibility() } }
    func applyRate() {
        windows.values.forEach { ($0 as? VideoWallpaperWindow)?.applyRate() }
    }

    /// Human-readable current description for menu title.
    var titleDescription: String? {
        let prefs = Preferences.shared
        if let g = prefs.globalSource { return g.displayName }
        return nil
    }

    @objc private func screensChanged() { rebuildAll() }

    private func rebuildAll() {
        for (_, w) in windows { w.tearDown() }
        windows.removeAll()
        let prefs = Preferences.shared
        for screen in NSScreen.screens {
            guard let src = prefs.resolveSource(for: screen) else { continue }
            guard let uuid = ScreenIdentity.uuid(for: screen) else { continue }
            let w: WallpaperWindow
            switch src {
            case .video(let url): w = VideoWallpaperWindow(screen: screen, videoURL: url)
            case .web(let url):   w = WebWallpaperWindow(screen: screen, pageURL: url)
            }
            w.show()
            windows[uuid] = w
        }
    }
}
