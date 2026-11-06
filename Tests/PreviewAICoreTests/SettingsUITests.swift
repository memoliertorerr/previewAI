import Foundation
import Testing
@testable import PreviewAICore

@MainActor
@Suite struct ShortcutRecorderModelTests {
    let control: UInt = 1 << 18, option: UInt = 1 << 19, shift: UInt = 1 << 17, command: UInt = 1 << 20

    @Test func ignoresKeysWhenNotRecording() {
        let model = ShortcutRecorderModel(combo: .default)
        #expect(model.handle(keyCode: 0x28, modifierFlags: command) == .ignored)
        #expect(model.combo == .default)
    }

    @Test func recordsAValidCombo() {
        let model = ShortcutRecorderModel(combo: .default)
        model.start()
        #expect(model.isRecording)
        let outcome = model.handle(keyCode: 0x28, modifierFlags: command | shift)
        #expect(outcome == .recorded(KeyCombo(keyCode: 0x28, modifiers: [.command, .shift])))
        #expect(model.combo.displayString == "⇧⌘K")
        #expect(!model.isRecording)
    }

    @Test func rejectsModifierLessKeysAndKeepsRecording() {
        let model = ShortcutRecorderModel(combo: .default)
        model.start()
        #expect(model.handle(keyCode: 0x28, modifierFlags: 0) == .rejected)
        #expect(model.handle(keyCode: 0x28, modifierFlags: shift) == .rejected)
        #expect(model.isRecording)
        #expect(model.hint?.contains("⌃ ⌥ ⌘") == true)
        #expect(model.combo == .default)
    }

    @Test func escCancelsWithoutChanging() {
        let model = ShortcutRecorderModel(combo: KeyCombo(keyCode: 0x28, modifiers: [.command]))
        model.start()
        #expect(model.handle(keyCode: 0x35, modifierFlags: 0) == .cancelled)
        #expect(!model.isRecording)
        #expect(model.combo.displayString == "⌘K")
    }

    @Test func deleteResetsToDefault() {
        let model = ShortcutRecorderModel(combo: KeyCombo(keyCode: 0x28, modifiers: [.command]))
        model.start()
        #expect(model.handle(keyCode: 0x33, modifierFlags: 0) == .cleared)
        #expect(model.combo == .default)
    }

    @Test func modifiedEscAndDeleteAreNormalCombos() {
        let model = ShortcutRecorderModel(combo: .default)
        model.start()
        #expect(model.handle(keyCode: 0x33, modifierFlags: command | option) == .recorded(KeyCombo(keyCode: 0x33, modifiers: [.command, .option])))
    }
}

@Suite struct ConnectionTesterTests {
    @Test func successQuotesTheReply() async {
        let provider = ScriptedProvider(displayName: "Claude", modelName: "claude-haiku-5-5", chunks: ["PreviewAI ", "connection OK"])
        let result = await ConnectionTester.run(provider)
        #expect(result == .success("Connected to Claude · claude-haiku-5-5 — it replied “PreviewAI connection OK”."))
        #expect(provider.calls.first?.maxOutputTokens == 50)
    }

    @Test func unavailableAndErrorsAreFailures() async {
        #expect(await ConnectionTester.run(ScriptedProvider(chunks: [], availability: .unavailable("No key."))) == .failure("No key."))
        #expect(await ConnectionTester.run(ScriptedProvider(chunks: ["x"], failure: .unauthorized)) == .failure(ProviderError.unauthorized.localizedDescription))
        #expect(await ConnectionTester.run(ScriptedProvider(chunks: [" "])) == .failure(ProviderError.emptyResponse.localizedDescription))
    }
}
