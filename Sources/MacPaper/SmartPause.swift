import AppKit

/// Auto-pauses wallpaper when a fullscreen app is front, or Low Power Mode is on.
final class SmartPause {
    static let shared = SmartPause()

    var onChange: ((Bool) -> Void)?   // true = should pause
    private(set) var isPaused = false
    private var timer: Timer?

    func start() {
        stop()
        let t = Timer(timeInterval: 2.0, target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t

        NotificationCenter.default.addObserver(self, selector: #selector(tick),
                                               name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                               object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(tick),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil)
        tick()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isPaused = false
    }

    @objc private func tick() {
        let prefs = Preferences.shared
        var shouldPause = false

        if prefs.smartPauseLowPower, ProcessInfo.processInfo.isLowPowerModeEnabled {
            shouldPause = true
        }

        if !shouldPause, prefs.smartPauseFullscreen, Self.anyScreenCoveredByFullscreenWindow() {
            shouldPause = true
        }

        if shouldPause != isPaused {
            isPaused = shouldPause
            onChange?(shouldPause)
        }
    }

    /// True if any visible window (layer 0, owned by another app) fully covers a screen.
    private static func anyScreenCoveredByFullscreenWindow() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let pid = ProcessInfo.processInfo.processIdentifier

        for screen in NSScreen.screens {
            let sf = screen.frame
            for w in list {
                guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                      let ownerPID = w[kCGWindowOwnerPID as String] as? Int, ownerPID != Int(pid),
                      let bounds = w[kCGWindowBounds as String] as? [String: CGFloat]
                else { continue }
                let wx = bounds["X"] ?? 0
                let wy = bounds["Y"] ?? 0
                let ww = bounds["Width"] ?? 0
                let wh = bounds["Height"] ?? 0
                // CGWindow coords: origin top-left of primary display. NSScreen: bottom-left.
                // Compare sizes — a fullscreen window matches a screen's size exactly.
                if abs(ww - sf.width) < 1 && abs(wh - sf.height) < 1 {
                    // Sanity: ignore Dock / status-bar-only windows via owner name blacklist.
                    let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
                    if owner == "Dock" || owner == "Window Server" { continue }
                    _ = wx; _ = wy
                    return true
                }
            }
        }
        return false
    }
}

// Bridging constant name not imported into Swift by default.
extension NSNotification.Name {
    static let NSProcessInfoPowerStateDidChange = Notification.Name("NSProcessInfoPowerStateDidChangeNotification")
}
