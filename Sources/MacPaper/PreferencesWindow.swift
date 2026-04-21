import AppKit
import SwiftUI
import AVFoundation

// MARK: - NSWindowController host

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let host = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: host)
        window.title = "MacPaper"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 860, height: 580))
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Store bridging Preferences + controller to SwiftUI

final class PrefsStore: ObservableObject {
    static let shared = PrefsStore()

    // Observable copies of prefs so SwiftUI re-renders on change.
    @Published var brightness: Double
    @Published var blurRadius: Double
    @Published var playbackRate: Double
    @Published var muted: Bool
    @Published var fitMode: FitMode

    @Published var playlistEnabled: Bool
    @Published var playlistShuffle: Bool
    @Published var playlistIntervalSec: Int

    @Published var smartPauseFullscreen: Bool
    @Published var smartPauseLowPower: Bool

    @Published var currentTitle: String = ""
    @Published var libraryItems: [URL] = []
    @Published var screens: [NSScreen] = NSScreen.screens
    @Published var licensed: Bool = License.shared.isLicensed
    @Published var licenseUser: String = License.shared.displayUser

    private init() {
        let p = Preferences.shared
        brightness = p.brightness
        blurRadius = p.blurRadius
        playbackRate = p.playbackRate
        muted = p.muted
        fitMode = p.fitMode
        playlistEnabled = p.playlistEnabled
        playlistShuffle = p.playlistShuffle
        playlistIntervalSec = p.playlistIntervalSec
        smartPauseFullscreen = p.smartPauseFullscreen
        smartPauseLowPower = p.smartPauseLowPower
        currentTitle = p.globalSource?.displayName ?? "—"
        libraryItems = Library.shared.items()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshLicense),
                                               name: .licenseDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshScreens),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func refreshLicense() {
        licensed = License.shared.isLicensed
        licenseUser = License.shared.displayUser
    }
    @objc private func refreshScreens() { screens = NSScreen.screens }

    func refreshCurrent() {
        currentTitle = Preferences.shared.globalSource?.displayName ?? "—"
        libraryItems = Library.shared.items()
    }

    // MARK: - Commands the UI invokes

    func applyBrightness()  { Preferences.shared.brightness = brightness;   WallpaperController.shared?.applyOverlay() }
    func applyBlur()        { Preferences.shared.blurRadius = blurRadius;   WallpaperController.shared?.applyOverlay() }
    func applyRate()        { Preferences.shared.playbackRate = playbackRate; WallpaperController.shared?.applyRate() }
    func applyMute()        { Preferences.shared.muted = muted;             WallpaperController.shared?.applyAudio() }
    func applyFit()         { Preferences.shared.fitMode = fitMode;         WallpaperController.shared?.applyFit() }

    func applyPlaylist() {
        Preferences.shared.playlistEnabled    = playlistEnabled
        Preferences.shared.playlistShuffle    = playlistShuffle
        Preferences.shared.playlistIntervalSec = playlistIntervalSec
        if playlistEnabled { Playlist.shared.start() } else { Playlist.shared.stop() }
    }

    func applySmartPause() {
        Preferences.shared.smartPauseFullscreen = smartPauseFullscreen
        Preferences.shared.smartPauseLowPower   = smartPauseLowPower
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        }
        if panel.runModal() == .OK, let url = panel.url {
            WallpaperController.shared?.setGlobal(source: .video(url))
            refreshCurrent()
        }
    }

    func openWebURL(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let url = URL(string: s) else { return }
        WallpaperController.shared?.setGlobal(source: .web(url))
        refreshCurrent()
    }

    func playFromLibrary(_ url: URL) {
        WallpaperController.shared?.setGlobal(source: .video(url))
        refreshCurrent()
    }

    func addToLibrary() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        }
        if panel.runModal() == .OK {
            Library.shared.import(urls: panel.urls)
            refreshCurrent()
        }
    }

    func assign(video: URL, to screen: NSScreen) {
        WallpaperController.shared?.setPerScreen(source: .video(video), screen: screen)
    }
    func clearAssignment(for screen: NSScreen) {
        WallpaperController.shared?.clearPerScreen(screen)
    }
    func resetAllAssignments() {
        Preferences.shared.clearAllAssignments()
        WallpaperController.shared?.start()
    }

    func stopWallpaper()  { WallpaperController.shared?.stop() }
    func startWallpaper() { WallpaperController.shared?.start() }
}

// MARK: - Root View

struct PreferencesView: View {
    @StateObject private var store = PrefsStore.shared
    @StateObject private var loc = Localizer.shared
    @State private var section: Section = .wallpaper

    enum Section: String, CaseIterable, Identifiable {
        case wallpaper, library, displays, adjustments, playback

        var id: String { rawValue }
        var locKey: String { "sec." + rawValue }

        var icon: String {
            switch self {
            case .wallpaper:   return "photo.tv"
            case .library:     return "rectangle.stack.fill"
            case .displays:    return "display.2"
            case .adjustments: return "slider.horizontal.3"
            case .playback:    return "play.rectangle.on.rectangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Color.white.opacity(0.06))
            content
        }
        .frame(minWidth: 820, minHeight: 540)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .environmentObject(store)
        .environmentObject(loc)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "photo.tv")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(loc.t("app.name")).font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 20)

            ForEach(Section.allCases) { s in
                SidebarRow(title: loc.t(s.locKey), icon: s.icon, selected: section == s) {
                    section = s
                }
            }
            Spacer()

            // Language switcher
            HStack(spacing: 4) {
                ForEach(AppLang.allCases) { code in
                    Button { loc.lang = code } label: {
                        Text(code.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(loc.lang == code ? Color.white : Color.white.opacity(0.06))
                            )
                            .foregroundColor(loc.lang == code ? .black : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)

            Spacer().frame(height: 16)
        }
        .frame(width: 210)
        .background(Color(white: 0.04))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Text(loc.t(section.locKey))
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.white)

                switch section {
                case .wallpaper:   WallpaperPanel()
                case .library:     LibraryPanel()
                case .displays:    DisplaysPanel()
                case .adjustments: AdjustmentsPanel()
                case .playback:    PlaybackPanel()
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Sidebar row

struct SidebarRow: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(title).font(.system(size: 13, weight: selected ? .semibold : .medium))
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.white.opacity(0.08) : Color.clear)
            )
            .foregroundColor(selected ? .white : Color.white.opacity(0.65))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
}

// MARK: - Reusable Card

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Wallpaper Panel

struct WallpaperPanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer
    @State private var webURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                        Image(systemName: "photo.tv")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 120, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc.t("wallpaper.current")).font(.system(size: 11)).foregroundColor(.secondary)
                        Text(store.currentTitle.isEmpty ? loc.t("wallpaper.none") : store.currentTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button(loc.t("common.stop"), action: store.stopWallpaper)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(loc.t("wallpaper.chooseSource")).font(.system(size: 11)).foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button { store.chooseVideo() } label: {
                            Label(loc.t("wallpaper.chooseVideo"), systemImage: "film")
                        }.buttonStyle(PrimaryButtonStyle())

                        Button { store.addToLibrary() } label: {
                            Label(loc.t("wallpaper.addLibrary"), systemImage: "plus.rectangle.on.rectangle")
                        }.buttonStyle(SecondaryButtonStyle())
                    }

                    Divider().overlay(Color.white.opacity(0.06)).padding(.vertical, 6)

                    HStack(spacing: 8) {
                        TextField(loc.t("wallpaper.urlPlaceholder"), text: $webURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08))))
                        Button(loc.t("common.apply")) {
                            store.openWebURL(webURL); webURL = ""
                        }.buttonStyle(PrimaryButtonStyle())
                            .disabled(webURL.isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Library Panel

struct LibraryPanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer
    let cols = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(format: loc.t("library.count"), store.libraryItems.count))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button { store.addToLibrary() } label: {
                    Label(loc.t("common.addFiles"), systemImage: "plus")
                }.buttonStyle(SecondaryButtonStyle())
            }

            if store.libraryItems.isEmpty {
                Card {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 28)).foregroundColor(.white.opacity(0.3))
                        Text(loc.t("library.empty.title"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(loc.t("library.empty.desc"))
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            } else {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(store.libraryItems, id: \.self) { url in
                        LibraryTile(url: url) { store.playFromLibrary(url) }
                    }
                }
            }
        }
    }
}

struct LibraryTile: View {
    let url: URL
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                    if let ns = Thumbnails.thumbnail(for: url) {
                        Image(nsImage: ns).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "film").font(.system(size: 22)).foregroundColor(.white.opacity(0.3))
                    }
                }
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(hover ? 0.25 : 0.08), lineWidth: 1))

                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.top, 6)
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Displays Panel

struct DisplaysPanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: loc.t("displays.connected"), store.screens.count))
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button(loc.t("common.resetAll")) { store.resetAllAssignments() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            ForEach(Array(store.screens.enumerated()), id: \.offset) { idx, screen in
                DisplayRow(screen: screen, index: idx)
            }
        }
    }
}

struct DisplayRow: View {
    let screen: NSScreen
    let index: Int
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer

    var body: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .frame(width: 80, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ScreenIdentity.label(for: screen, index: index))
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(Int(screen.frame.width)) × \(Int(screen.frame.height))")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    if let a = Preferences.shared.assignment(for: screen) {
                        Text("• \(URL(string: a.value)?.lastPathComponent ?? a.value)")
                            .font(.system(size: 11)).foregroundColor(.accentColor).lineLimit(1)
                    } else {
                        Text(loc.t("displays.usingGlobal"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(loc.t("common.assign")) { pick() }.buttonStyle(PrimaryButtonStyle())
                Button(loc.t("common.reset"))  { store.clearAssignment(for: screen) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        }
        if panel.runModal() == .OK, let url = panel.url {
            store.assign(video: url, to: screen)
        }
    }
}

// MARK: - Adjustments Panel

struct AdjustmentsPanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 20) {
                    SliderRow(label: loc.t("adj.brightness"), value: $store.brightness,
                              range: 0...1, step: 0.01,
                              format: "%.2f", onCommit: store.applyBrightness)
                    Divider().overlay(Color.white.opacity(0.05))
                    SliderRow(label: loc.t("adj.blur"), value: $store.blurRadius,
                              range: 0...40, step: 1,
                              format: "%.0f", onCommit: store.applyBlur)
                    Divider().overlay(Color.white.opacity(0.05))
                    SliderRow(label: loc.t("adj.speed"), value: $store.playbackRate,
                              range: 0.25...2.0, step: 0.05,
                              format: "%.2fx", onCommit: store.applyRate)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $store.muted) {
                        Text(loc.t("adj.mute")).font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .onChange(of: store.muted) { _ in store.applyMute() }

                    Divider().overlay(Color.white.opacity(0.05))

                    HStack {
                        Text(loc.t("adj.fit")).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $store.fitMode) {
                            ForEach(FitMode.allCases, id: \.self) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: store.fitMode) { _ in store.applyFit() }
                    }
                }
            }
        }
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(.white)
                .onChange(of: value) { _ in onCommit() }
        }
    }
}

// MARK: - Playback Panel

struct PlaybackPanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $store.playlistEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t("play.playlist")).font(.system(size: 13, weight: .medium))
                            Text(loc.t("play.playlist.desc"))
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .onChange(of: store.playlistEnabled) { _ in store.applyPlaylist() }

                    Toggle(isOn: $store.playlistShuffle) {
                        Text(loc.t("play.shuffle")).font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .onChange(of: store.playlistShuffle) { _ in store.applyPlaylist() }

                    HStack {
                        Text(loc.t("play.interval")).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $store.playlistIntervalSec) {
                            Text(loc.t("play.int.1m")).tag(60)
                            Text(loc.t("play.int.5m")).tag(300)
                            Text(loc.t("play.int.15m")).tag(900)
                            Text(loc.t("play.int.30m")).tag(1800)
                            Text(loc.t("play.int.1h")).tag(3600)
                            Text(loc.t("play.int.4h")).tag(14400)
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: store.playlistIntervalSec) { _ in store.applyPlaylist() }
                    }

                    HStack {
                        Spacer()
                        Button { Playlist.shared.next() } label: {
                            Label(loc.t("play.advanceNow"), systemImage: "forward.end.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(loc.t("play.smartPause")).font(.system(size: 13, weight: .semibold))
                    Toggle(isOn: $store.smartPauseFullscreen) {
                        Text(loc.t("play.sp.fullscreen")).font(.system(size: 13))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .onChange(of: store.smartPauseFullscreen) { _ in store.applySmartPause() }

                    Toggle(isOn: $store.smartPauseLowPower) {
                        Text(loc.t("play.sp.lowpower")).font(.system(size: 13))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .onChange(of: store.smartPauseLowPower) { _ in store.applySmartPause() }
                }
            }
        }
    }
}

// MARK: - License Panel

struct LicensePanel: View {
    @EnvironmentObject var store: PrefsStore
    @EnvironmentObject var loc: Localizer
    @State private var keyInput = ""
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Circle().fill(store.licensed ? Color.green : Color.orange).frame(width: 8, height: 8)
                        Text(store.licensed ? loc.t("lic.licensed") : loc.t("lic.unlicensed"))
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        if store.licensed {
                            Text(store.licenseUser).foregroundColor(.secondary).font(.system(size: 12))
                        }
                    }
                    if !status.isEmpty {
                        Text(status).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(loc.t("lic.key")).font(.system(size: 11)).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        TextField("MPRO-XXXX-XXXX-XXXX-XXXX", text: $keyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08))))
                        Button(loc.t("common.paste")) {
                            if let s = NSPasteboard.general.string(forType: .string) {
                                keyInput = License.normalizeKey(s)
                            }
                        }.buttonStyle(SecondaryButtonStyle())
                        Button(loc.t("lic.activate")) { activate() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(keyInput.isEmpty)
                    }
                    HStack {
                        Button { License.shared.openBotBuyLink() } label: {
                            Label(loc.t("lic.buyTelegram"), systemImage: "paperplane.fill")
                        }.buttonStyle(SecondaryButtonStyle())

                        if store.licensed {
                            Button(loc.t("common.signOut")) {
                                License.shared.signOut()
                            }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func activate() {
        status = loc.t("lic.status.contacting")
        let key = License.normalizeKey(keyInput)
        let done: (Result<License.Info, Error>) -> Void = { result in
            switch result {
            case .success: status = loc.t("lic.status.activated")
                NotificationCenter.default.post(name: .licenseDidChange, object: nil)
            case .failure(let e): status = "✗ " + e.localizedDescription
            }
        }
        if let existing = License.shared.info, existing.key == key {
            License.shared.revalidate(completion: done)
        } else {
            License.shared.activate(key: key, completion: done)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.white.opacity(0.85) : Color.white)
            )
            .foregroundColor(.black)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .foregroundColor(.white.opacity(0.9))
    }
}
