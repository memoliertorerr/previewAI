import Foundation

public enum ProviderID: String, Codable, CaseIterable, Sendable {
    case appleIntelligence, anthropic, openAICompatible, claudeCode, codex

    public var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .anthropic: "Anthropic API"
        case .openAICompatible: "OpenAI-compatible"
        case .claudeCode: "Claude subscription"
        case .codex: "Codex subscription"
        }
    }
}

/// One summarization call, already rendered into provider-neutral messages.
public struct SummaryRequest: Sendable, Equatable {
    public var system: String
    public var user: String
    public var maxOutputTokens: Int

    public init(system: String, user: String, maxOutputTokens: Int) {
        self.system = system
        self.user = user
        self.maxOutputTokens = maxOutputTokens
    }
}

public enum ProviderAvailability: Sendable, Equatable {
    case ready
    case unavailable(String)
}

/// A backend that turns a `SummaryRequest` into streamed text.
public protocol SummaryProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    /// The model in use, shown in the panel and part of the cache key.
    var modelName: String { get }
    /// Characters of document text this provider can take in one request.
    var inputBudget: Int { get }
    func availability() async -> ProviderAvailability
    /// Streams text deltas. Cancelling the consuming task must stop the work.
    func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error>
}

public enum ProviderError: LocalizedError, Equatable, Sendable {
    case notConfigured(String)
    case unauthorized
    case rateLimited
    case refused
    case http(Int, String)
    case network(String)
    case process(String)
    case unavailable(String)
    case emptyResponse
    /// The prompt didn't fit the model's context window. The session retries with less text.
    case contextTooLong

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let what): "\(Self.sentence(what)) Open Settings to finish setup."
        case .unauthorized: "The API key was rejected — check it in Settings."
        case .rateLimited: "The provider is rate-limiting requests — try again in a moment."
        case .refused: "The model declined to summarize this document."
        case .http(let code, let message):
            switch (code, message.isEmpty) {
            case (0, true): "The provider returned an error."
            case (0, false): Self.sentence("The provider returned an error: \(message)")
            case (_, true): "The provider returned an error (HTTP \(code))."
            case (_, false): Self.sentence("The provider returned an error (HTTP \(code)): \(message)")
            }
        case .network(let message): Self.sentence(message)
        case .process(let message): Self.sentence(message)
        case .unavailable(let reason): Self.sentence(reason)
        case .emptyResponse: "The model returned an empty summary — try again."
        case .contextTooLong: "This document is too long for the selected model. Choose a provider with a larger context in Settings."
        }
    }

    /// Server and CLI text arrives without consistent punctuation; make it read as a sentence.
    static func sentence(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if !".!?”)".contains(last) { trimmed += "." }
        if let first = trimmed.first, first.isLowercase { trimmed = first.uppercased() + trimmed.dropFirst() }
        return trimmed
    }
}
