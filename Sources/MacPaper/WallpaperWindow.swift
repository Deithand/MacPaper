import AppKit
import AVFoundation
import AVKit
import WebKit

/// Base: borderless, click-through, desktop-level window + brightness/blur overlay.
class WallpaperWindow: NSWindow {
    let containerView = NSView()
    private let overlayLayer = CALayer()
    private let blurHostLayer = CALayer()

    init(screen: NSScreen) {
        super.init(
            contentRect: NSRect(origin: .zero, size: screen.frame.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)

        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        sharingType = .readOnly

        containerView.frame = NSRect(origin: .zero, size: screen.frame.size)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer = CALayer()
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        contentView = containerView

        // Overlay layer (darkening) sits on top of content.
        overlayLayer.backgroundColor = NSColor.black.cgColor
        overlayLayer.frame = containerView.bounds
        overlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        overlayLayer.zPosition = 1000
    }

    /// Subclasses add their content (player / web) to this layer.
    var contentLayer: CALayer { containerView.layer! }

    func installOverlay() {
        contentLayer.addSublayer(overlayLayer)
        installWatermark()
        applyOverlay()
    }

    private let watermarkLayer = CATextLayer()
    private func installWatermark() {
        let w: CGFloat = 320, h: CGFloat = 22
        let b = containerView.bounds
        watermarkLayer.frame = CGRect(x: b.width - w - 24, y: 24, width: w, height: h)
        watermarkLayer.string = "MacPaper · UNLICENSED — t.me/\(License.shared.botUsername)"
        watermarkLayer.fontSize = 13
        watermarkLayer.alignmentMode = .right
        watermarkLayer.foregroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        watermarkLayer.shadowColor = NSColor.black.cgColor
        watermarkLayer.shadowOpacity = 0.7
        watermarkLayer.shadowRadius = 3
        watermarkLayer.shadowOffset = .zero
        watermarkLayer.contentsScale = containerView.window?.backingScaleFactor ?? 2
        watermarkLayer.zPosition = 1001
        watermarkLayer.autoresizingMask = [.layerMinXMargin, .layerMaxYMargin]
        contentLayer.addSublayer(watermarkLayer)
        updateWatermarkVisibility()
    }

    func updateWatermarkVisibility() {
        watermarkLayer.isHidden = License.shared.isLicensed
    }

    func applyOverlay() {
        // Brightness 1.0 = full video, 0.0 = black.
        let b = max(0, min(1, Preferences.shared.brightness))
        overlayLayer.opacity = Float(1.0 - b)

        let r = CGFloat(max(0, Preferences.shared.blurRadius))
        if r > 0.1 {
            let blur = CIFilter(name: "CIGaussianBlur")
            blur?.setValue(r, forKey: "inputRadius")
            if let f = blur {
                contentLayer.filters = [f]
            }
        } else {
            contentLayer.filters = nil
        }
    }

    func show() { orderFrontRegardless() }

    func tearDown() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        orderOut(nil)
        close()
    }

    // Hooks subclasses override.
    func applyAudio() {}
    func applyFit()   {}
    func pausePlayback() {}
    func resumePlayback() {}

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Video backend

final class VideoWallpaperWindow: WallpaperWindow {
    private let videoURL: URL
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    init(screen: NSScreen, videoURL: URL) {
        self.videoURL = videoURL
        super.init(screen: screen)
        setupPlayer()
        installOverlay()

        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(onSleep),
                         name: NSWorkspace.willSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(onWake),
                         name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func setupPlayer() {
        let item = AVPlayerItem(url: videoURL)
        let queue = AVQueuePlayer()
        queue.actionAtItemEnd = .advance
        queue.automaticallyWaitsToMinimizeStalling = false
        let loop = AVPlayerLooper(player: queue, templateItem: item)

        let layer = AVPlayerLayer(player: queue)
        layer.frame = containerView.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        contentLayer.addSublayer(layer)

        self.player = queue
        self.looper = loop
        self.playerLayer = layer

        applyFit()
        applyAudio()
        applyRate()
        queue.play()
    }

    @objc private func onSleep() { player?.pause() }
    @objc private func onWake()  { if !SmartPause.shared.isPaused { player?.play() } }

    override func applyAudio() {
        player?.isMuted = Preferences.shared.muted
        player?.volume = Preferences.shared.muted ? 0 : 1
    }

    override func applyFit() {
        switch Preferences.shared.fitMode {
        case .fill:    playerLayer?.videoGravity = .resizeAspectFill
        case .fit:     playerLayer?.videoGravity = .resizeAspect
        case .stretch: playerLayer?.videoGravity = .resize
        }
    }

    func applyRate() {
        player?.rate = Preferences.shared.muted ? Float(Preferences.shared.playbackRate) : Float(Preferences.shared.playbackRate)
    }

    override func pausePlayback() { player?.pause() }
    override func resumePlayback() { player?.play() }

    override func tearDown() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        looper = nil
        player = nil
        super.tearDown()
    }
}

// MARK: - Web backend

final class WebWallpaperWindow: WallpaperWindow {
    private let pageURL: URL
    private var webView: WKWebView!

    init(screen: NSScreen, pageURL: URL) {
        self.pageURL = pageURL
        super.init(screen: screen)
        setupWebView()
        installOverlay()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: containerView.bounds, configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground") // transparent bg
        wv.load(URLRequest(url: pageURL))
        // Make the webview fill behind the overlay layer.
        containerView.addSubview(wv, positioned: .below, relativeTo: nil)
        self.webView = wv
    }

    override func pausePlayback() {
        webView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v=>v.pause())", completionHandler: nil)
    }
    override func resumePlayback() {
        webView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v=>v.play())", completionHandler: nil)
    }

    override func tearDown() {
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        super.tearDown()
    }
}
