import Foundation
import Observation

/// What the panel shows about the document being summarized.
public struct DocumentInfo: Sendable, Equatable {
    public var url: URL
    public var title: String
    public var kind: DocumentKind?
    public var pageCount: Int?
    /// Set when only part of the document fit the provider's budget.
    public var truncationNote: String?

    public init(url: URL) {
        self.url = url
        self.title = url.lastPathComponent
        self.kind = DocumentLoader.kind(for: url)
    }
}

/// Drives one summary at a time: load → budget → (cache) → stream. The panel renders `state`.
@MainActor
@Observable
public final class SummarySession {
    public enum State: Equatable, Sendable {
        case idle
        case loading(DocumentInfo)
        case streaming(DocumentInfo, String)
        case finished(DocumentInfo, String)
        case failed(DocumentInfo?, String)
    }

    public private(set) var state: State = .idle {
        didSet { stateDidChange?(state) }
    }
    /// Name of the provider/model producing the current summary.
    public private(set) var providerLabel: String = ""
    public private(set) var length: SummaryLength = .standard
    /// True when the current failure is about the provider (off, not set up, key rejected),
    /// so the panel can offer "Open Settings".
    public private(set) var failureNeedsSettings = false

    @ObservationIgnored public var stateDidChange: (@MainActor (State) -> Void)?
    @ObservationIgnored private let loader: DocumentLoader
    @ObservationIgnored private let cache: SummaryCache
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var last: (url: URL, provider: any SummaryProvider)?

    public init(loader: DocumentLoader = DocumentLoader(), cache: SummaryCache = SummaryCache()) {
        self.loader = loader
        self.cache = cache
    }

    public var isWorking: Bool {
        switch state {
        case .loading, .streaming: true
        default: false
        }
    }

    public func summarize(url: URL, provider: any SummaryProvider, length: SummaryLength, useCache: Bool = true) {
        task?.cancel()
        generation += 1
        let current = generation
        last = (url, provider)
        self.length = length
        failureNeedsSettings = false
        providerLabel = provider.modelName.isEmpty ? provider.displayName : "\(provider.displayName) · \(provider.modelName)"
        state = .loading(DocumentInfo(url: url))
        task = Task { [weak self] in
            await self?.run(url: url, provider: provider, length: length, useCache: useCache, generation: current)
        }
    }

    /// Runs the last request again, skipping the cache. Optionally with a new length.
    public func regenerate(length newLength: SummaryLength? = nil) {
        guard let last else { return }
        summarize(url: last.url, provider: last.provider, length: newLength ?? length, useCache: newLength != nil)
    }

    public func cancel() {
        task?.cancel()
        task = nil
        generation += 1
        state = .idle
    }

    /// Shows a message without a document (e.g. "Select a document in Finder first").
    public func showMessage(_ message: String) {
        cancel()
        failureNeedsSettings = false
        state = .failed(nil, message)
    }

    /// Cancels work and forgets the last request and its text (frees memory when the panel closes).
    public func close() {
        cancel()
        last = nil
        providerLabel = ""
    }

    /// Waits for the running summary (if any) to settle. Mainly for tests.
    public func waitUntilSettled() async {
        await task?.value
    }

    private func run(url: URL, provider: any SummaryProvider, length: SummaryLength, useCache: Bool, generation current: Int) async {
        var info = DocumentInfo(url: url)

        if case .unavailable(let reason) = await provider.availability() {
            finish(.failed(info, reason), needsSettings: true, generation: current)
            return
        }

        let document: DocumentContent
        do {
            document = try await loader.load(url).budgeted(maxCharacters: provider.inputBudget)
        } catch {
            finish(.failed(info, error.localizedDescription), generation: current)
            return
        }
        info.kind = document.kind
        info.pageCount = document.pageCount
        if document.isTruncated {
            info.truncationNote = "Summarized the first \(Int((document.fractionIncluded * 100).rounded()))% — the document is longer than this provider can take."
        }
        guard current == generation else { return }
        state = .loading(info)

        let key = SummaryCache.Key(url: url, provider: provider.id, model: provider.modelName, length: length)
        if useCache, let cached = cache.value(for: key) {
            finish(.finished(info, cached), generation: current)
            return
        }

        var text = ""
        do {
            for try await chunk in provider.stream(PromptBuilder.request(for: document, length: length)) {
                guard current == generation, !Task.isCancelled else { return }
                text += chunk
                state = .streaming(info, text)
            }
        } catch is CancellationError {
            return
        } catch {
            let needsSettings: Bool = switch error as? ProviderError {
            case .notConfigured, .unauthorized, .unavailable: true
            default: false
            }
            finish(.failed(info, error.localizedDescription), needsSettings: needsSettings, generation: current)
            return
        }
        guard current == generation, !Task.isCancelled else { return }

        let summary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            finish(.failed(info, ProviderError.emptyResponse.localizedDescription), generation: current)
            return
        }
        cache.store(summary, for: key)
        finish(.finished(info, summary), generation: current)
    }

    private func finish(_ newState: State, needsSettings: Bool = false, generation current: Int) {
        guard current == generation else { return }
        failureNeedsSettings = needsSettings
        state = newState
    }
}
