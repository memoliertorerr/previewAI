import Foundation

/// Streams canned chunks. Powers the debug "Demo summary" and the unit tests.
public final class ScriptedProvider: SummaryProvider, @unchecked Sendable {
    public let id: ProviderID
    public let displayName: String
    public let modelName: String
    public let inputBudget: Int
    private let chunks: [String]
    private let delay: Duration
    private let failure: ProviderError?
    private let available: ProviderAvailability
    private let maxPromptCharacters: Int?

    private let lock = NSLock()
    private var _calls: [SummaryRequest] = []
    private var _terminations = 0

    public init(
        id: ProviderID = .appleIntelligence,
        displayName: String = "Demo",
        modelName: String = "scripted",
        inputBudget: Int = 100_000,
        chunks: [String],
        delay: Duration = .zero,
        failure: ProviderError? = nil,
        availability: ProviderAvailability = .ready,
        maxPromptCharacters: Int? = nil
    ) {
        self.maxPromptCharacters = maxPromptCharacters
        self.id = id
        self.displayName = displayName
        self.modelName = modelName
        self.inputBudget = inputBudget
        self.chunks = chunks
        self.delay = delay
        self.failure = failure
        self.available = availability
    }

    public var calls: [SummaryRequest] { lock.withLock { _calls } }
    public var terminations: Int { lock.withLock { _terminations } }

    public func availability() async -> ProviderAvailability { available }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        lock.withLock { _calls.append(request) }
        let chunks = chunks, delay = delay, failure = failure
        if let maxPromptCharacters, request.user.count > maxPromptCharacters {
            return AsyncThrowingStream { $0.finish(throwing: ProviderError.contextTooLong) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    if delay > .zero { try? await Task.sleep(for: delay) }
                    if Task.isCancelled { break }
                    continuation.yield(chunk)
                }
                if let failure { continuation.finish(throwing: failure) } else { continuation.finish() }
            }
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.lock.withLock { self?._terminations += 1 }
            }
        }
    }
}
