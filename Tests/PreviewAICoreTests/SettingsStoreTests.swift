import Foundation
import Testing
@testable import PreviewAICore

@MainActor
@Suite struct SettingsStoreTests {
    func make() -> (SettingsStore, InMemoryKeyValueStore, InMemorySecretStore) {
        let store = InMemoryKeyValueStore()
        let secrets = InMemorySecretStore()
        return (SettingsStore(store: store, secrets: secrets), store, secrets)
    }

    @Test func defaults() {
        let (settings, store, _) = make()
        #expect(settings.selectedProvider == .appleIntelligence)
        #expect(settings.length == .standard)
        #expect(settings.shortcut == .default)
        #expect(settings.shortcut.displayString == "⌥⇧Space")
        #expect(settings.anthropic.model == "claude-opus-5-5")
        #expect(settings.openAICompatible.preset == .openAI)
        #expect(settings.openAICompatible.effectiveBaseURL == "https://api.openai.com/v1")
        #expect(settings.claudeCode == CLIConfig())
        #expect(!settings.launchAtLogin)
        #expect(store.values.isEmpty)  // loading writes nothing
    }

    @Test func everySettingRoundTrips() {
        let (settings, store, secrets) = make()
        settings.selectedProvider = .openAICompatible
        settings.length = .detailed
        settings.shortcut = KeyCombo(keyCode: 0x28, modifiers: [.command, .shift])
        settings.launchAtLogin = true
        settings.anthropic.model = "claude-haiku-5-5"
        settings.openAICompatible.preset = .ollama
        settings.openAICompatible.model = "llama3.2"
        settings.claudeCode.binaryPath = "/opt/homebrew/bin/claude"
        settings.codex.model = "gpt-test"

        let reloaded = SettingsStore(store: store, secrets: secrets)
        #expect(reloaded.selectedProvider == .openAICompatible)
        #expect(reloaded.length == .detailed)
        #expect(reloaded.shortcut.displayString == "⇧⌘K")
        #expect(reloaded.launchAtLogin)
        #expect(reloaded.anthropic.model == "claude-haiku-5-5")
        #expect(reloaded.openAICompatible.preset == .ollama)
        #expect(reloaded.openAICompatible.effectiveBaseURL == "http://localhost:11434/v1")
        #expect(reloaded.openAICompatible.model == "llama3.2")
        #expect(reloaded.claudeCode.binaryPath == "/opt/homebrew/bin/claude")
        #expect(reloaded.codex.model == "gpt-test")
    }

    @Test func apiKeysOnlyGoToTheSecretStore() throws {
        let (settings, store, secrets) = make()
        let key = "sk-ant-test-0123456789abcdef"
        try settings.setAPIKey("  \(key)\n", for: .anthropic)
        settings.anthropic.model = "claude-sonnet-5-5"  // force some settings writes too

        #expect(settings.apiKey(for: .anthropic) == key)
        #expect(secrets.secret(for: "anthropic") == key)
        for (name, data) in store.values {
            #expect(!String(decoding: data, as: UTF8.self).contains(key), "key leaked into \(name)")
        }
        try settings.setAPIKey("", for: .anthropic)
        #expect(settings.apiKey(for: .anthropic) == nil)
    }

    @Test func openAICompatibleKeysArePerPreset() throws {
        let (settings, _, _) = make()
        try settings.setAPIKey("sk-openai", for: .openAICompatible)
        settings.openAICompatible.preset = .custom
        #expect(settings.apiKey(for: .openAICompatible) == nil)
        try settings.setAPIKey("custom-key", for: .openAICompatible)
        settings.openAICompatible.preset = .openAI
        #expect(settings.apiKey(for: .openAICompatible) == "sk-openai")
    }

    @Test func providersWithoutKeysIgnoreThem() throws {
        let (settings, _, secrets) = make()
        try settings.setAPIKey("x", for: .appleIntelligence)
        #expect(settings.apiKey(for: .appleIntelligence) == nil)
        #expect(secrets.secret(for: "appleIntelligence") == nil)
    }

    @Test func customBaseURLOverridesPreset() {
        var config = OpenAICompatibleConfig()
        config.preset = .lmStudio
        #expect(config.effectiveBaseURL == "http://localhost:1234/v1")
        config.baseURL = "  http://10.0.0.5:8080/v1 "
        #expect(config.effectiveBaseURL == "http://10.0.0.5:8080/v1")
    }
}
