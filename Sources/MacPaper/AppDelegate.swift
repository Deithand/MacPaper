import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var dropView: DropTargetView!
    private let controller = WallpaperController()
    private let prefs = Preferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        controller.onStateChange = { [weak self] in self?.rebuildMenu() }

        // Global hotkey: next wallpaper.
        Hotkeys.shared.onNext = { [weak self] in self?.playNext() }
        Hotkeys.shared.install()

        // Playlist auto-start if enabled.
        if prefs.playlistEnabled { Playlist.shared.start() }

        // Start wallpapers (from saved global + per-screen assignments).
        controller.start()

        // React to license changes: refresh menu + watermark visibility.
        NotificationCenter.default.addObserver(forName: .licenseDidChange,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.controller.applyLicense()
            self?.rebuildMenu()
        }
        License.shared.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.controller.applyLicense()
                self?.rebuildMenu()
            }
        }

        // Pro gating disabled — no blocking license check at startup.

        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Hotkeys.shared.uninstall()
        Playlist.shared.stop()
        SmartPause.shared.stop()
        controller.stop()
    }

    // MARK: - Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let btn = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "photo.tv", accessibilityDescription: "MacPaper")
        img?.isTemplate = true
        btn.image = img

        // Drop target overlay for drag-and-drop video files onto the menu-bar icon.
        let drop = DropTargetView(frame: btn.bounds)
        drop.autoresizingMask = [.width, .height]
        drop.button = btn
        drop.onDrop = { [weak self] urls in
            guard let self = self, let first = urls.first else { return }
            Library.shared.import(urls: urls)
            let imported = Library.shared.folder.appendingPathComponent(first.lastPathComponent)
            let toUse = FileManager.default.fileExists(atPath: imported.path) ? imported : first
            self.controller.setGlobal(source: .video(toUse))
        }
        btn.addSubview(drop)
        dropView = drop
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: controller.isRunning ? "MacPaper · playing" : "MacPaper · idle",
                               action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if let desc = controller.titleDescription {
            let f = NSMenuItem(title: "  " + desc, action: nil, keyEquivalent: "")
            f.isEnabled = false
            menu.addItem(f)
        }
        menu.addItem(.separator())

        menu.addItem(item("Choose Video…", #selector(chooseVideo), key: "o"))
        menu.addItem(item("Open Web URL…", #selector(openURL), key: "u"))

        let lib = NSMenuItem(title: "Library", action: nil, keyEquivalent: "")
        lib.submenu = buildLibraryMenu(); menu.addItem(lib)

        let apply = NSMenuItem(title: "Apply to Screen", action: nil, keyEquivalent: "")
        apply.submenu = buildApplyToMenu(); menu.addItem(apply)

        menu.addItem(.separator())

        let adj = NSMenuItem(title: "Adjustments", action: nil, keyEquivalent: "")
        adj.submenu = buildAdjustmentsMenu(); menu.addItem(adj)

        let pl = NSMenuItem(title: "Playlist", action: nil, keyEquivalent: "")
        pl.submenu = buildPlaylistMenu(); menu.addItem(pl)

        let sp = NSMenuItem(title: "Smart Pause", action: nil, keyEquivalent: "")
        sp.submenu = buildSmartPauseMenu(); menu.addItem(sp)

        menu.addItem(.separator())
        if controller.isRunning {
            menu.addItem(item("Stop", #selector(stop), key: "s"))
        } else {
            menu.addItem(item("Start", #selector(start), key: "s"))
        }
        menu.addItem(item("Next Wallpaper  ⌃⌥⌘→", #selector(playNext), key: ""))
        menu.addItem(item("Preferences…", #selector(showPreferences), key: ","))
        let login = item("Launch at Login", #selector(toggleLoginItem), key: "")
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Reveal Library in Finder", #selector(revealLibrary), key: ""))
        menu.addItem(item("About MacPaper", #selector(about), key: ""))
        menu.addItem(item("Quit", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func buildLibraryMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let items = Library.shared.items()
        if items.isEmpty {
            let i = NSMenuItem(title: "Empty — drop .mp4/.mov files here", action: nil, keyEquivalent: "")
            i.isEnabled = false
            m.addItem(i)
        } else {
            for url in items {
                let i = NSMenuItem(title: url.lastPathComponent, action: #selector(playLibraryItem(_:)), keyEquivalent: "")
                i.target = self
                i.representedObject = url
                i.image = Thumbnails.thumbnail(for: url)
                if case .video(let current) = prefs.globalSource, current == url { i.state = .on }
                m.addItem(i)
            }
        }
        m.addItem(.separator())
        m.addItem(item("Add Files to Library…", #selector(addToLibrary), key: ""))
        m.addItem(item("Open Library Folder", #selector(revealLibrary), key: ""))
        return m
    }

    private func buildApplyToMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        m.addItem(item("All Screens (pick video…)", #selector(applyAllScreensFromPicker), key: ""))
        m.addItem(.separator())
        for (idx, screen) in NSScreen.screens.enumerated() {
            let name = ScreenIdentity.label(for: screen, index: idx)
            let current = prefs.assignment(for: screen)
            let label = current.map { "\(name) — " + (URL(string: $0.value)?.lastPathComponent ?? $0.value) } ?? name
            let sub = NSMenu()
            sub.autoenablesItems = false
            sub.addItem(itemWithObj("Choose Video for This Screen…",
                                    #selector(applyPerScreenVideo(_:)), obj: screen))
            sub.addItem(itemWithObj("Set Web URL for This Screen…",
                                    #selector(applyPerScreenWeb(_:)), obj: screen))
            sub.addItem(.separator())
            sub.addItem(itemWithObj("Reset (use global)",
                                    #selector(clearPerScreen(_:)), obj: screen))
            let i = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            i.submenu = sub
            m.addItem(i)
        }
        m.addItem(.separator())
        m.addItem(item("Reset All Per-Screen Overrides", #selector(resetAllPerScreen), key: ""))
        return m
    }

    private func buildAdjustmentsMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false

        m.addItem(sliderItem(title: "Brightness",
                             value: prefs.brightness, min: 0, max: 1,
                             tag: 1, action: #selector(sliderChanged(_:))))
        m.addItem(sliderItem(title: "Blur",
                             value: prefs.blurRadius, min: 0, max: 40,
                             tag: 2, action: #selector(sliderChanged(_:))))
        m.addItem(sliderItem(title: "Speed",
                             value: prefs.playbackRate, min: 0.25, max: 2.0,
                             tag: 3, action: #selector(sliderChanged(_:))))

        m.addItem(.separator())
        let mute = item(prefs.muted ? "Unmute" : "Mute", #selector(toggleMute), key: "m")
        mute.state = prefs.muted ? .off : .on
        m.addItem(mute)

        let fit = NSMenuItem(title: "Fit", action: nil, keyEquivalent: "")
        let fitMenu = NSMenu()
        for mode in FitMode.allCases {
            let mi = NSMenuItem(title: mode.label, action: #selector(setFit(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = mode.rawValue
            mi.state = (prefs.fitMode == mode) ? .on : .off
            fitMenu.addItem(mi)
        }
        fit.submenu = fitMenu
        m.addItem(fit)
        return m
    }

    private func buildPlaylistMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let en = item("Enabled", #selector(togglePlaylist), key: "")
        en.state = prefs.playlistEnabled ? .on : .off
        m.addItem(en)
        let sh = item("Shuffle", #selector(togglePlaylistShuffle), key: "")
        sh.state = prefs.playlistShuffle ? .on : .off
        m.addItem(sh)

        m.addItem(.separator())
        let intervals: [(Int, String)] = [
            (60,    "Every 1 minute"),
            (300,   "Every 5 minutes"),
            (900,   "Every 15 minutes"),
            (1800,  "Every 30 minutes"),
            (3600,  "Every 1 hour"),
            (14400, "Every 4 hours")
        ]
        for (sec, label) in intervals {
            let i = NSMenuItem(title: label, action: #selector(setInterval(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = sec
            i.state = (prefs.playlistIntervalSec == sec) ? .on : .off
            m.addItem(i)
        }
        m.addItem(.separator())
        m.addItem(item("Advance Now", #selector(playNext), key: ""))
        return m
    }

    private func buildSmartPauseMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let fs = item("Pause on Fullscreen App", #selector(toggleSmartPauseFullscreen), key: "")
        fs.state = prefs.smartPauseFullscreen ? .on : .off
        m.addItem(fs)
        let lp = item("Pause in Low Power Mode", #selector(toggleSmartPauseLowPower), key: "")
        lp.state = prefs.smartPauseLowPower ? .on : .off
        m.addItem(lp)
        m.addItem(.separator())
        let stat = SmartPause.shared.isPaused ? "Currently: PAUSED" : "Currently: playing"
        let s = NSMenuItem(title: stat, action: nil, keyEquivalent: "")
        s.isEnabled = false
        m.addItem(s)
        return m
    }

    // MARK: - Helpers

    private func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func itemWithObj(_ title: String, _ action: Selector, obj: Any) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.representedObject = obj
        return i
    }

    private func sliderItem(title: String, value: Double, min: Double, max: Double,
                            tag: Int, action: Selector) -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 44))
        let label = NSTextField(labelWithString: "\(title): \(Self.fmt(value))")
        label.frame = NSRect(x: 14, y: 24, width: 212, height: 16)
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.tag = tag + 100
        container.addSubview(label)

        let slider = NSSlider(value: value, minValue: min, maxValue: max,
                              target: self, action: action)
        slider.frame = NSRect(x: 14, y: 4, width: 212, height: 20)
        slider.tag = tag
        slider.isContinuous = true
        container.addSubview(slider)

        let mi = NSMenuItem()
        mi.view = container
        return mi
    }

    private static func fmt(_ v: Double) -> String {
        if abs(v - round(v)) < 0.05 { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    // MARK: - Actions

    @objc private func chooseVideo() {
        guard let url = pickVideoFile() else { return }
        controller.setGlobal(source: .video(url))
    }

    @objc private func openURL() {
        guard let url = promptForURL() else { return }
        prefs.lastVideoURL = nil
        // Clear per-screen so global web applies everywhere.
        prefs.clearAllAssignments()
        for screen in NSScreen.screens {
            prefs.setAssignment(ScreenAssignment(kind: .web, value: url.absoluteString), for: screen)
        }
        controller.start()
    }

    @objc private func playLibraryItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        controller.setGlobal(source: .video(url))
    }

    @objc private func applyAllScreensFromPicker() {
        guard let url = pickVideoFile() else { return }
        prefs.clearAllAssignments()
        controller.setGlobal(source: .video(url))
    }

    @objc private func applyPerScreenVideo(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen,
              let url = pickVideoFile() else { return }
        controller.setPerScreen(source: .video(url), screen: screen)
    }

    @objc private func applyPerScreenWeb(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen,
              let url = promptForURL() else { return }
        controller.setPerScreen(source: .web(url), screen: screen)
    }

    @objc private func clearPerScreen(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        controller.clearPerScreen(screen)
    }

    @objc private func resetAllPerScreen() {
        prefs.clearAllAssignments()
        controller.start()
    }

    @objc private func start() { controller.start(); rebuildMenu() }
    @objc private func stop()  { controller.stop(); rebuildMenu() }

    @objc private func toggleMute() {
        prefs.muted.toggle(); controller.applyAudio(); rebuildMenu()
    }

    @objc private func setFit(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = FitMode(rawValue: raw) else { return }
        prefs.fitMode = mode
        controller.applyFit()
        rebuildMenu()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let v = sender.doubleValue
        switch sender.tag {
        case 1: prefs.brightness = v;    controller.applyOverlay()
        case 2: prefs.blurRadius = v;    controller.applyOverlay()
        case 3: prefs.playbackRate = v;  controller.applyRate()
        default: break
        }
        // Update the label next to the slider in the same container.
        if let container = sender.superview,
           let label = container.viewWithTag(sender.tag + 100) as? NSTextField {
            let parts = label.stringValue.split(separator: ":")
            if let name = parts.first {
                label.stringValue = "\(name): \(Self.fmt(v))"
            }
        }
    }

    @objc private func togglePlaylist() {
        prefs.playlistEnabled.toggle()
        if prefs.playlistEnabled { Playlist.shared.start() } else { Playlist.shared.stop() }
        rebuildMenu()
    }
    @objc private func togglePlaylistShuffle() {
        prefs.playlistShuffle.toggle()
        if prefs.playlistEnabled { Playlist.shared.start() }
        rebuildMenu()
    }
    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let sec = sender.representedObject as? Int else { return }
        prefs.playlistIntervalSec = sec
        if prefs.playlistEnabled { Playlist.shared.start() }
        rebuildMenu()
    }
    @objc private func playNext() { Playlist.shared.next() }

    @objc private func toggleSmartPauseFullscreen() {
        prefs.smartPauseFullscreen.toggle(); rebuildMenu()
    }
    @objc private func toggleSmartPauseLowPower() {
        prefs.smartPauseLowPower.toggle(); rebuildMenu()
    }

    @objc private func toggleLoginItem() { LoginItem.toggle(); rebuildMenu() }

    @objc private func addToLibrary() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        }
        if panel.runModal() == .OK {
            Library.shared.import(urls: panel.urls)
            rebuildMenu()
        }
    }

    @objc private func revealLibrary() { NSWorkspace.shared.open(Library.shared.folder) }

    @objc private func about() {
        let a = NSAlert()
        a.messageText = "MacPaper 0.2"
        a.informativeText = """
        Open-source animated wallpaper engine for macOS.
        """
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showLicenseWindow() { LicenseWindowController.shared.show() }
    @objc private func showPreferences() { PreferencesWindowController.shared.show() }
    @objc private func buyLicense() { License.shared.openBotBuyLink() }
    @objc private func signOutLicense() {
        License.shared.signOut()
        controller.applyLicense()
        rebuildMenu()
    }

    // MARK: - Pickers / prompts

    private func pickVideoFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func promptForURL() -> URL? {
        let alert = NSAlert()
        alert.messageText = "Web Wallpaper"
        alert.informativeText = "Enter an http(s) URL to render as a wallpaper."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        tf.placeholderString = "https://example.com"
        alert.accessoryView = tf
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return nil }
        var s = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        return URL(string: s)
    }
}
