import Foundation

/// A global keyboard shortcut: a virtual key code plus modifiers. Pure data so it can be
/// persisted and tested; the app turns it into a Carbon hotkey.
public struct KeyCombo: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥⇧Space. (⌃Space and ⌃⌥Space are macOS input-source shortcuts.)
    public static let `default` = KeyCombo(keyCode: KeyCode.space, modifiers: [.option, .shift])

    /// Builds a combo from an `NSEvent` key code and `NSEvent.ModifierFlags.rawValue`.
    /// Returns nil when the result isn't usable as a global shortcut.
    public init?(keyCode: UInt16, modifierFlagsRawValue flags: UInt) {
        var modifiers: Modifiers = []
        if flags & EventFlag.control != 0 { modifiers.insert(.control) }
        if flags & EventFlag.option != 0 { modifiers.insert(.option) }
        if flags & EventFlag.shift != 0 { modifiers.insert(.shift) }
        if flags & EventFlag.command != 0 { modifiers.insert(.command) }
        self.init(keyCode: UInt32(keyCode), modifiers: modifiers)
        guard isValid else { return nil }
    }

    /// A global shortcut needs a modifier (shift alone isn't enough) — except function keys.
    public var isValid: Bool {
        if KeyCode.functionKeys.contains(keyCode) { return true }
        guard KeyCode.names[keyCode] != nil else { return false }
        return !modifiers.subtracting(.shift).isEmpty
    }

    /// Apple's order: ⌃⌥⇧⌘, then the key.
    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + (KeyCode.names[keyCode] ?? "Key \(keyCode)")
    }

    /// Modifier mask for Carbon's `RegisterEventHotKey` (values from `Carbon.HIToolbox`).
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= 0x0100 }  // cmdKey
        if modifiers.contains(.shift) { mask |= 0x0200 }    // shiftKey
        if modifiers.contains(.option) { mask |= 0x0800 }   // optionKey
        if modifiers.contains(.control) { mask |= 0x1000 }  // controlKey
        return mask
    }
}

/// `NSEvent.ModifierFlags` bit values, so Core doesn't need AppKit.
enum EventFlag {
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20
}

/// Virtual key codes (ANSI layout, from `Carbon.HIToolbox` `kVK_*`).
public enum KeyCode {
    public static let space: UInt32 = 0x31
    public static let escape: UInt32 = 0x35
    public static let delete: UInt32 = 0x33

    static let functionKeys: Set<UInt32> = [0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F]

    static let names: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F", 0x05: "G", 0x04: "H",
        0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P",
        0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6", 0x1A: "7",
        0x1C: "8", 0x19: "9",
        0x31: "Space", 0x24: "Return", 0x30: "Tab", 0x33: "Delete", 0x35: "Esc",
        0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]", 0x29: ";", 0x27: "'", 0x2A: "\\", 0x2B: ",",
        0x2F: ".", 0x2C: "/", 0x32: "`",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
        0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]
}
