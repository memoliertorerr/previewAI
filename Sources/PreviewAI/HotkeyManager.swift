import Carbon.HIToolbox
import Foundation
import PreviewAICore

/// One global hotkey via Carbon `RegisterEventHotKey` — no Accessibility permission needed,
/// and it works inside the App Sandbox.
@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    private(set) var combo: KeyCombo?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x5076_4149  // "PvAI"

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { manager.onPress?() }
            return noErr
        }, 1, &eventType, context, &handlerRef)
    }

    /// Replaces the current hotkey. Returns false if macOS refused the combo (e.g. it's taken).
    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            hotKeyRef = nil
            return false
        }
        self.combo = combo
        return true
    }

    /// True if an enabled macOS shortcut (System Settings → Keyboard → Keyboard Shortcuts) uses
    /// this combo. macOS handles those first, so our hotkey would never fire — and
    /// `RegisterEventHotKey` doesn't report the clash.
    static func isReservedBySystem(_ combo: KeyCombo) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        let relevant: UInt32 = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        return array.contains { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = (entry[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value,
                  let mods = (entry[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value
            else { return false }
            return code == combo.keyCode && (mods & relevant) == combo.carbonModifiers
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        combo = nil
    }
}
