import Foundation

/// Everything the summary panel displays, derived from `SummarySession.State`. Pure, so the
/// panel's behavior is testable without a window.
public struct PanelContent: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var body: String
    public var fileURL: URL?
    public var isWorking: Bool
    /// True while text is arriving (show a subtle indicator, not a spinner).
    public var isStreaming: Bool
    public var error: String?
    public var truncationNote: String?
    public var canCopy: Bool
    public var canRegenerate: Bool

    public init(state: SummarySession.State, additionalFiles: Int = 0) {
        title = "PreviewAI"
        subtitle = ""
        body = ""
        fileURL = nil
        isWorking = false
        isStreaming = false
        error = nil
        truncationNote = nil
        canCopy = false
        canRegenerate = false

        let info: DocumentInfo?
        switch state {
        case .idle:
            info = nil
        case .loading(let i):
            info = i
            isWorking = true
        case .streaming(let i, let text):
            info = i
            body = text
            isWorking = true
            isStreaming = true
        case .finished(let i, let text):
            info = i
            body = text
            canCopy = true
            canRegenerate = true
        case .failed(let i, let message):
            info = i
            error = message
            canRegenerate = i != nil
        }

        guard let info else { return }
        title = info.title
        fileURL = info.url
        truncationNote = info.truncationNote
        var parts: [String] = []
        if let kind = info.kind { parts.append(kind.displayName) }
        if let pages = info.pageCount { parts.append(pages == 1 ? "1 page" : "\(pages) pages") }
        if additionalFiles > 0 { parts.append("+\(additionalFiles) more selected") }
        subtitle = parts.joined(separator: " · ")
    }
}
