import Foundation

public enum DocumentKind: String, Sendable, Codable, CaseIterable {
    case pdf, markdown, plainText, richText, word, html

    public var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .markdown: "Markdown"
        case .plainText: "Text"
        case .richText: "Rich Text"
        case .word: "Word"
        case .html: "HTML"
        }
    }
}

/// Text extracted from a document, ready to be put into a prompt.
public struct DocumentContent: Sendable, Equatable {
    public var url: URL
    public var title: String
    public var kind: DocumentKind
    public var text: String
    public var pageCount: Int?
    /// Character count of the full extracted text, before any budgeting.
    public var originalLength: Int
    public var isTruncated: Bool

    public init(url: URL, kind: DocumentKind, text: String, pageCount: Int? = nil) {
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.kind = kind
        self.text = text
        self.pageCount = pageCount
        self.originalLength = text.count
        self.isTruncated = false
    }

    /// Share of the original text that is included (1.0 when nothing was cut).
    public var fractionIncluded: Double {
        guard originalLength > 0 else { return 1 }
        return min(1, Double(text.count) / Double(originalLength))
    }

    /// Returns a copy whose text fits `maxCharacters`, cut at the last paragraph break
    /// (or whitespace) before the limit so the model never sees half a word.
    public func budgeted(maxCharacters: Int) -> DocumentContent {
        guard maxCharacters > 0, text.count > maxCharacters else { return self }
        let limit = text.index(text.startIndex, offsetBy: maxCharacters)
        let head = text[..<limit]
        // Prefer a paragraph break in the last 20% of the window; otherwise any whitespace.
        let minimumCut = text.index(text.startIndex, offsetBy: maxCharacters * 4 / 5)
        var cut = limit
        if let paragraph = head.range(of: "\n\n", options: .backwards), paragraph.lowerBound >= minimumCut {
            cut = paragraph.lowerBound
        } else if let space = head.lastIndex(where: { $0.isWhitespace }) {
            cut = space
        }
        var copy = self
        copy.text = String(text[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        copy.isTruncated = true
        return copy
    }
}

public enum DocumentError: LocalizedError, Equatable, Sendable {
    case unsupported(String)
    case noText
    case tooLarge
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            "PreviewAI can't read “\(name)” — try a PDF, Markdown, text, RTF, Word or HTML file."
        case .noText:
            "This document has no selectable text (it may be a scanned PDF)."
        case .tooLarge:
            "This file is larger than 200 MB, which is too big to summarize."
        case .unreadable(let name):
            "PreviewAI couldn't open “\(name)”."
        }
    }
}
