import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model (macOS 26+). Free, private, and offline — but with a small context
/// window, so long documents are budgeted down and the panel says so.
public struct AppleIntelligenceProvider: SummaryProvider {
    public let id = ProviderID.appleIntelligence
    public let displayName = "Apple Intelligence"
    public let modelName = ""

    /// Output is capped so prompt + answer stay inside the on-device context window.
    static let maxOutputTokens = 1_000
    /// Tokens kept for instructions, the prompt wrapper, and the answer.
    static let reservedTokens = 1_600
    /// Conservative characters-per-token for mixed-language text.
    static let charactersPerToken = 3

    public init() {}

    /// Characters of document text that fit a context of `contextSize` tokens.
    static func budget(contextSize: Int) -> Int {
        max(2_000, (contextSize - reservedTokens) * charactersPerToken)
    }

    public var inputBudget: Int {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            return Self.budget(contextSize: SystemLanguageModel.default.contextSize)
        }
        #endif
        return Self.budget(contextSize: 4_096)
    }

    public func availability() async -> ProviderAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.deviceNotEligible):
                return .unavailable("This Mac doesn't support Apple Intelligence. Choose another provider in PreviewAI Settings.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Apple Intelligence is turned off. Turn it on in System Settings → Apple Intelligence & Siri, or choose another provider.")
            case .unavailable(.modelNotReady):
                return .unavailable("Apple Intelligence is still getting its model ready. Try again in a few minutes.")
            case .unavailable:
                return .unavailable("Apple Intelligence isn't available right now. Choose another provider in PreviewAI Settings.")
            }
        }
        #endif
        return .unavailable("Apple Intelligence needs macOS 26 or later. Choose another provider in PreviewAI Settings.")
    }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let session = LanguageModelSession(instructions: request.system)
                        let options = GenerationOptions(maximumResponseTokens: min(request.maxOutputTokens, Self.maxOutputTokens))
                        var deltas = DeltaTracker()
                        for try await snapshot in session.streamResponse(to: request.user, options: options) {
                            let delta = deltas.next(snapshot.content)
                            if !delta.isEmpty { continuation.yield(delta) }
                        }
                        continuation.finish()
                    } catch let error as LanguageModelSession.GenerationError {
                        continuation.finish(throwing: Self.map(error))
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        #endif
        return AsyncThrowingStream { $0.finish(throwing: ProviderError.unavailable("Apple Intelligence needs macOS 26 or later.")) }
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    static func map(_ error: LanguageModelSession.GenerationError) -> ProviderError {
        switch error {
        case .exceededContextWindowSize:
            .unavailable("This document is too long for Apple Intelligence. Choose a cloud or local provider in Settings for long documents.")
        case .guardrailViolation, .refusal:
            .refused
        case .unsupportedLanguageOrLocale:
            .unavailable("Apple Intelligence doesn't support this document's language yet.")
        case .assetsUnavailable:
            .unavailable("Apple Intelligence is still getting its model ready. Try again in a few minutes.")
        case .rateLimited, .concurrentRequests:
            .rateLimited
        default:
            .unavailable(error.localizedDescription)
        }
    }
    #endif
}

/// FoundationModels streams cumulative snapshots; the provider contract wants deltas.
struct DeltaTracker {
    private var sent = ""

    mutating func next(_ snapshot: String) -> String {
        defer { sent = snapshot }
        if snapshot.hasPrefix(sent) {
            return String(snapshot.dropFirst(sent.count))
        }
        // The model revised earlier text; emit only what extends the common prefix.
        let common = zip(sent, snapshot).prefix(while: { $0 == $1 }).count
        return String(snapshot.dropFirst(max(common, sent.count)))
    }
}
