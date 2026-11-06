import Foundation

/// Builds the provider the user selected. Settings-driven from PA7 on.
@MainActor
public final class ProviderRegistry {
    public var selected: ProviderID

    public init(selected: ProviderID = .appleIntelligence) {
        self.selected = selected
    }

    public var current: any SummaryProvider {
        switch selected {
        case .appleIntelligence:
            AppleIntelligenceProvider()
        default:
            UnavailableProvider(id: selected, reason: "\(selected.displayName) isn't set up yet.")
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
