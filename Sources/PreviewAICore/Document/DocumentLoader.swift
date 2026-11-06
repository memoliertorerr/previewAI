import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Extracts plain text from supported document types.
public struct DocumentLoader: Sendable {
    public static let maxFileSize = 200 * 1024 * 1024

    public init() {}

    /// Loads and extracts text. Extraction is CPU work, so it runs off the caller's actor —
    /// except HTML, whose importer is WebKit-backed and must run on the main thread.
    public func load(_ url: URL) async throws -> DocumentContent {
        if Self.kind(for: url) == .html {
            return try await MainActor.run { try Self.loadSync(url) }
        }
        return try await Task.detached(priority: .userInitiated) {
            try Self.loadSync(url)
        }.value
    }

    public static func kind(for url: URL) -> DocumentKind? {
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdown", "mkd"].contains(ext) { return .markdown }
        guard let type = UTType(filenameExtension: ext) else { return nil }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .html) { return .html }
        if type.conforms(to: .rtf) || type.conforms(to: .rtfd) { return .richText }
        if let docx = UTType("org.openxmlformats.wordprocessingml.document"), type.conforms(to: docx) { return .word }
        if type.conforms(to: .plainText) || type.conforms(to: .sourceCode) { return .plainText }
        return nil
    }

    static func loadSync(_ url: URL) throws -> DocumentContent {
        let name = url.lastPathComponent
        guard let kind = kind(for: url) else { throw DocumentError.unsupported(name) }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxFileSize else { throw DocumentError.tooLarge }

        var pageCount: Int?
        let raw: String
        switch kind {
        case .pdf:
            guard let pdf = PDFDocument(url: url) else { throw DocumentError.unreadable(name) }
            pageCount = pdf.pageCount
            raw = (0..<pdf.pageCount)
                .compactMap { pdf.page(at: $0)?.string }
                .joined(separator: "\n\n")
        case .markdown, .plainText:
            raw = try readText(url, name: name)
        case .richText, .word, .html:
            let type: NSAttributedString.DocumentType = switch kind {
            case .richText: url.pathExtension.lowercased() == "rtfd" ? .rtfd : .rtf
            case .word: .officeOpenXML
            default: .html
            }
            do {
                raw = try NSAttributedString(
                    url: url,
                    options: [.documentType: type, .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
                ).string
            } catch {
                throw DocumentError.unreadable(name)
            }
        }

        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DocumentError.noText }
        return DocumentContent(url: url, kind: kind, text: text, pageCount: pageCount)
    }

    private static func readText(_ url: URL, name: String) throws -> String {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) { return utf8 }
        var encoding = String.Encoding.utf8
        if let guessed = try? String(contentsOf: url, usedEncoding: &encoding) { return guessed }
        throw DocumentError.unreadable(name)
    }
}
