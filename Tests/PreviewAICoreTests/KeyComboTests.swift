import Foundation
import Testing
@testable import PreviewAICore

@Suite struct KeyComboTests {
    @Test func roundTripsThroughCodable() throws {
        let combo = KeyCombo(keyCode: 0x28, modifiers: [.command, .shift])
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: JSONEncoder().encode(combo))
        #expect(decoded == combo)
    }

    @Test func displayUsesAppleModifierOrder() {
        #expect(KeyCombo.default.displayString == "⌃⌥Space")
        #expect(KeyCombo(keyCode: 0x28, modifiers: [.command, .shift]).displayString == "⇧⌘K")
        #expect(KeyCombo(keyCode: 0x01, modifiers: [.command, .shift, .option, .control]).displayString == "⌃⌥⇧⌘S")
    }

    @Test func convertsEventFlagsToCarbon() throws {
        // NSEvent.ModifierFlags: control 1<<18, option 1<<19, command 1<<20; plus noise bits.
        let flags: UInt = (1 << 18) | (1 << 19) | (1 << 8)
        let combo = try #require(KeyCombo(keyCode: 0x31, modifierFlagsRawValue: flags))
        #expect(combo == .default)
        #expect(combo.carbonModifiers == 0x1000 | 0x0800)
        let cmdShift = try #require(KeyCombo(keyCode: 0x28, modifierFlagsRawValue: (1 << 20) | (1 << 17)))
        #expect(cmdShift.carbonModifiers == 0x0100 | 0x0200)
    }

    @Test func rejectsCombosWithoutModifiers() {
        #expect(KeyCombo(keyCode: 0x28, modifierFlagsRawValue: 0) == nil)
        #expect(KeyCombo(keyCode: 0x28, modifierFlagsRawValue: 1 << 17) == nil)  // shift only
        #expect(KeyCombo(keyCode: 0x7A, modifierFlagsRawValue: 0) != nil)        // F1 alone is fine
        #expect(KeyCombo(keyCode: 0xFF, modifierFlagsRawValue: 1 << 20) == nil)  // unknown key
    }
}

@Suite struct EntryPointTests {
    @Test func keepsOnlyExistingFiles() throws {
        let dir = try TestSupport.scratch()
        let file = dir.appendingPathComponent("a.md")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        let folder = dir.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let package = dir.appendingPathComponent("notes.rtfd", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let missing = dir.appendingPathComponent("missing.pdf")
        let web = URL(string: "https://example.com/a.pdf")!

        #expect(EntryPoint.resolveFiles([file, folder, package, missing, web]) == [file, package])
    }
}
