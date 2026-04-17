import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: no Dock icon, menu bar only.
app.setActivationPolicy(.accessory)
app.run()
