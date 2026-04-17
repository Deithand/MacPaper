import AppKit

final class LicenseWindowController: NSWindowController, NSTextFieldDelegate {
    static let shared = LicenseWindowController()

    private let keyField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let activateBtn = NSButton(title: "Activate", target: nil, action: nil)

    private init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        win.title = "MacPaper · License"
        win.isReleasedWhenClosed = false
        win.center()
        super.init(window: win)
        buildUI()
        refreshStatus()
        License.shared.onChange = { [weak self] in DispatchQueue.main.async { self?.refreshStatus() } }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true

        let title = NSTextField(labelWithString: "MacPaper Pro")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.frame = NSRect(x: 24, y: 232, width: 300, height: 28)
        content.addSubview(title)

        statusLabel.frame = NSRect(x: 24, y: 204, width: 412, height: 22)
        statusLabel.textColor = .secondaryLabelColor
        content.addSubview(statusLabel)

        let keyLabel = NSTextField(labelWithString: "License key")
        keyLabel.frame = NSRect(x: 24, y: 172, width: 200, height: 18)
        keyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        keyLabel.textColor = .secondaryLabelColor
        content.addSubview(keyLabel)

        keyField.frame = NSRect(x: 24, y: 138, width: 412, height: 28)
        keyField.placeholderString = "MPRO-XXXX-XXXX-XXXX-XXXX"
        keyField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        keyField.delegate = self
        content.addSubview(keyField)

        activateBtn.frame = NSRect(x: 332, y: 96, width: 104, height: 32)
        activateBtn.bezelStyle = .rounded
        activateBtn.keyEquivalent = "\r"
        activateBtn.target = self
        activateBtn.action = #selector(activate)
        content.addSubview(activateBtn)

        let pasteBtn = NSButton(title: "Paste", target: self, action: #selector(paste))
        pasteBtn.frame = NSRect(x: 254, y: 96, width: 72, height: 32)
        pasteBtn.bezelStyle = .rounded
        content.addSubview(pasteBtn)

        let buyBtn = NSButton(title: "Buy on Telegram…", target: self, action: #selector(buy))
        buyBtn.frame = NSRect(x: 24, y: 96, width: 160, height: 32)
        buyBtn.bezelStyle = .rounded
        content.addSubview(buyBtn)

        let help = NSTextField(wrappingLabelWithString:
            "Buy a key via the Telegram bot, then paste it here. " +
            "The key binds to this Mac (hardware ID). " +
            "Without a license MacPaper runs in trial mode with a watermark.")
        help.frame = NSRect(x: 24, y: 16, width: 412, height: 64)
        help.font = .systemFont(ofSize: 11)
        help.textColor = .tertiaryLabelColor
        content.addSubview(help)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refreshStatus() {
        if License.shared.isLicensed, let info = License.shared.info {
            statusLabel.stringValue = "✓ Licensed to \(License.shared.displayUser) · plan: \(info.plan)"
            statusLabel.textColor = .systemGreen
            keyField.stringValue = info.key
            activateBtn.title = "Re-validate"
        } else if let info = License.shared.info {
            statusLabel.stringValue = "Expired / offline grace ended — revalidate or enter a new key."
            statusLabel.textColor = .systemOrange
            keyField.stringValue = info.key
            activateBtn.title = "Validate"
        } else {
            statusLabel.stringValue = "No license — enter a key or buy one on Telegram."
            statusLabel.textColor = .secondaryLabelColor
            activateBtn.title = "Activate"
        }
    }

    @objc private func buy() { License.shared.openBotBuyLink() }

    @objc private func paste() {
        if let s = NSPasteboard.general.string(forType: .string) {
            keyField.stringValue = License.normalizeKey(s)
        }
    }

    @objc private func activate() {
        let k = License.normalizeKey(keyField.stringValue)
        guard !k.isEmpty else {
            statusLabel.stringValue = "Please paste a key first."
            statusLabel.textColor = .systemRed
            return
        }
        statusLabel.stringValue = "Contacting server…"
        statusLabel.textColor = .secondaryLabelColor
        activateBtn.isEnabled = false

        let done: (Result<License.Info, Error>) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.activateBtn.isEnabled = true
            switch result {
            case .success:
                self.refreshStatus()
                NotificationCenter.default.post(name: .licenseDidChange, object: nil)
            case .failure(let e):
                self.statusLabel.stringValue = "✗ " + e.localizedDescription
                self.statusLabel.textColor = .systemRed
            }
        }

        // If same key already stored — revalidate; else activate (HWID bind).
        if let existing = License.shared.info, existing.key == k {
            License.shared.revalidate(completion: done)
        } else {
            License.shared.activate(key: k, completion: done)
        }
    }
}

extension Notification.Name {
    static let licenseDidChange = Notification.Name("MacPaper.licenseDidChange")
}
