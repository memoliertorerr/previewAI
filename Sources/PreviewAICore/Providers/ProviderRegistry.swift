import Foundation

/// Builds the provider the user selected, from current settings.
@MainActor
public final class ProviderRegistry {
    public let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Providers offered in this build (CLI ones are compiled out of the App Store build).
    public static var availableIDs: [ProviderID] {
        #if APPSTORE
        [.appleIntelligence, .anthropic, .openAICompatible]
        #else
        ProviderID.allCases
        #endif
    }

    public var current: any SummaryProvider {
        provider(for: settings.selectedProvider)
    }

    public func provider(for id: ProviderID) -> any SummaryProvider {
        switch id {
        case .appleIntelligence:
            AppleIntelligenceProvider()
        case .anthropic:
            AnthropicProvider(apiKey: settings.apiKey(for: .anthropic), model: settings.anthropic.model)
        case .openAICompatible:
            OpenAICompatibleProvider(config: settings.openAICompatible, apiKey: settings.apiKey(for: .openAICompatible))
        #if APPSTORE
        case .claudeCode, .codex:
            UnavailableProvider(id: id, reason: "\(id.displayName) isn't available in the App Store version of PreviewAI.")
        #else
        case .claudeCode:
            ClaudeCodeProvider(config: settings.claudeCode)
        case .codex:
            CodexProvider(config: settings.codex)
        #endif
        }
    }
}

/// Stands in for a provider that can't run; the session shows its reason.
public struct UnavailableProvider: SummaryProvider {
    public let id: ProviderID
    public let reason: String
    public var displayName: String { id.displayName }
    public let modelName = ""
    public let inputBudget = 0

    public init(id: ProviderID, reason: String) {
        self.id = id
        self.reason = reason
    }

    public func availability() async -> ProviderAvailability { .unavailable(reason) }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: ProviderError.unavailable(reason)) }
    }
}
