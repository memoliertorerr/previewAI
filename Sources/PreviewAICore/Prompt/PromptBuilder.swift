import Foundation

/// Renders a document into the provider-neutral request every backend receives.
public enum PromptBuilder {
    public static let system = """
    You summarize documents for someone deciding whether and how to read them.
    Be faithful to the document: never add facts, opinions, or advice that are not in it.
    Write in the same language as the document. Use Markdown. Start directly with the summary — no preamble, no closing remarks.
    """

    public static func request(for document: DocumentContent, length: SummaryLength) -> SummaryRequest {
        var header = "Title: \(document.title)\nType: \(document.kind.displayName)"
        if let pages = document.pageCount { header += "\nPages: \(pages)" }

        var instructions = length.instruction
        if document.isTruncated {
            let percent = Int((document.fractionIncluded * 100).rounded())
            instructions += " Only the first \(percent)% of the document is included; say so in one short line at the end."
        }

        let user = """
        \(header)

        <document>
        \(document.text)
        </document>

        \(instructions)
        """
        return SummaryRequest(system: system, user: user, maxOutputTokens: length.maxOutputTokens)
    }
}
