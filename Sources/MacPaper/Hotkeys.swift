import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey: ⌃⌥⌘→ advances to the next wallpaper.
final class Hotkeys {
    static let shared = Hotkeys()

    var onNext: (() -> Void)?

    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let signature: OSType = 0x4D504150 // 'MPAP'

    func install() {
        uninstall()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, ud in
            guard let event = event, let ud = ud else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let me = Unmanaged<Hotkeys>.fromOpaque(ud).takeUnretainedValue()
            if hkID.id == 1 { me.onNext?() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        let hkID = EventHotKeyID(signature: signature, id: 1)
        // ⌃⌥⌘ + RightArrow (0x7C)
        let mods: UInt32 = UInt32(cmdKey | optionKey | controlKey)
        let key:  UInt32 = 0x7C
        RegisterEventHotKey(key, mods, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func uninstall() {
        if let hk = hotKeyRef { UnregisterEventHotKey(hk); hotKeyRef = nil }
        if let h = handlerRef { RemoveEventHandler(h); handlerRef = nil }
    }
}
