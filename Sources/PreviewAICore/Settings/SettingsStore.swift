import Foundation
import Observation

/// All user settings. Non-secret values persist as JSON in a `KeyValueStore`; API keys go only
/// to the `SecretStore` (Keychain).
@MainActor
@Observable
public final class SettingsStore {
    public var selectedProvider: ProviderID = .appleIntelligence { didSet { save(selectedProvider, "selectedProvider") } }
    public var length: SummaryLength = .standard { didSet { save(length, "length") } }
    public var shortcut: KeyCombo = .default { didSet { save(shortcut, "shortcut") } }
    public var launchAtLogin = false { didSet { save(launchAtLogin, "launchAtLogin") } }
    public var anthropic = AnthropicConfig() { didSet { save(anthropic, "anthropic") } }
    public var openAICompatible = OpenAICompatibleConfig() { didSet { save(openAICompatible, "openAICompatible") } }
    public var claudeCode = CLIConfig() { didSet { save(claudeCode, "claudeCode") } }
    public var codex = CLIConfig() { didSet { save(codex, "codex") } }

    @ObservationIgnored private let store: KeyValueStore
    @ObservationIgnored private let secrets: SecretStore
    /// With @Observable, assignments in init go through the observed setter and fire didSet,
    /// so saving is suppressed until loading is done.
    @ObservationIgnored private var isLoading = true
    /// Bumped when a key changes so views that show "key saved" refresh.
    public private(set) var secretsVersion = 0

    private static let prefix = "settings."

    public init(store: KeyValueStore, secrets: SecretStore) {
        self.store = store
        self.secrets = secrets
        selectedProvider = load("selectedProvider") ?? selectedProvider
        length = load("length") ?? length
        shortcut = load("shortcut") ?? shortcut
        launchAtLogin = load("launchAtLogin") ?? launchAtLogin
        anthropic = load("anthropic") ?? anthropic
        openAICompatible = load("openAICompatible") ?? openAICompatible
        claudeCode = load("claudeCode") ?? claudeCode
        codex = load("codex") ?? codex
        isLoading = false
    }

    // MARK: API keys

    /// Keychain account for a provider's key. OpenAI-compatible keys are per preset, so an
    /// OpenAI key isn't sent to a custom endpoint.
    public func secretAccount(for provider: ProviderID) -> String? {
        switch provider {
        case .anthropic: "anthropic"
        case .openAICompatible: "openAICompatible.\(openAICompatible.preset.rawValue)"
        case .appleIntelligence, .claudeCode, .codex: nil
        }
    }

    public func apiKey(for provider: ProviderID) -> String? {
        _ = secretsVersion  // observation dependency
        guard let account = secretAccount(for: provider) else { return nil }
        return secrets.secret(for: account)
    }

    public func setAPIKey(_ key: String?, for provider: ProviderID) throws {
        guard let account = secretAccount(for: provider) else { return }
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        try secrets.setSecret(trimmed, for: account)
        secretsVersion += 1
    }

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T, _ key: String) {
        guard !isLoading else { return }
        store.set(try? JSONEncoder().encode(value), forKey: Self.prefix + key)
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = store.data(forKey: Self.prefix + key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
