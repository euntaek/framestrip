import Carbon
import AppKit

class GlobalHotkeyManager {
    typealias HotkeyAction = @MainActor () -> Void

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: HotkeyAction?

    private static var sharedInstance: GlobalHotkeyManager?

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping HotkeyAction) {
        unregister()
        self.action = action
        GlobalHotkeyManager.sharedInstance = self

        // Convert NSEvent modifier flags to Carbon modifier mask
        var carbonModifiers: UInt32 = 0
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 { carbonModifiers |= UInt32(cmdKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 { carbonModifiers |= UInt32(optionKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbonModifiers |= UInt32(shiftKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 { carbonModifiers |= UInt32(controlKey) }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x46534E50) // "FSNP"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, _, _ -> OSStatus in
            GlobalHotkeyManager.sharedInstance?.action?()
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        action = nil
    }

    deinit { unregister() }
}
