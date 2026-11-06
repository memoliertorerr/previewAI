import Foundation
import Observation

/// The logic behind the shortcut recorder control: what each key press means while recording.
@MainActor
@Observable
public final class ShortcutRecorderModel {
    public enum Outcome: Equatable {
        case ignored, cancelled, cleared, recorded(KeyCombo), rejected
    }

    public private(set) var isRecording = false
    public private(set) var hint: String?
    public private(set) var combo: KeyCombo

    public init(combo: KeyCombo) {
        self.combo = combo
    }

    public func start() {
        isRecording = true
        hint = "Press the new shortcut — Esc cancels, Delete resets to \(KeyCombo.default.displayString)."
    }

    public func cancel() {
        isRecording = false
        hint = nil
    }

    /// Feed a key-down while recording. `modifierFlags` is `NSEvent.ModifierFlags.rawValue`.
    @discardableResult
    public func handle(keyCode: UInt16, modifierFlags: UInt) -> Outcome {
        guard isRecording else { return .ignored }
        let hasModifiers = !Self.modifiers(modifierFlags).isEmpty
        if UInt32(keyCode) == KeyCode.escape && !hasModifiers {
            cancel()
            return .cancelled
        }
        if UInt32(keyCode) == KeyCode.delete && !hasModifiers {
            combo = .default
            cancel()
            return .cleared
        }
        guard let recorded = KeyCombo(keyCode: keyCode, modifierFlagsRawValue: modifierFlags) else {
            hint = "Use at least one of ⌃ ⌥ ⌘ with a key (function keys work alone)."
            return .rejected
        }
        combo = recorded
        cancel()
        return .recorded(recorded)
    }

    private static func modifiers(_ flags: UInt) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags & EventFlag.control != 0 { modifiers.insert(.control) }
        if flags & EventFlag.option != 0 { modifiers.insert(.option) }
        if flags & EventFlag.shift != 0 { modifiers.insert(.shift) }
        if flags & EventFlag.command != 0 { modifiers.insert(.command) }
        return modifiers
    }
}
