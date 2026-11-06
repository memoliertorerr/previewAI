import Foundation

/// Splits model output into the few block types a summary uses, so the panel can render
/// headings and lists properly (SwiftUI's `AttributedString(markdown:)` handles inline styles
/// only). Tolerates partial input — it's re-run on every streamed chunk.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case bullet(indent: Int, text: String)
    case numbered(number: String, indent: Int, text: String)
    case paragraph(String)
    case rule

    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let indent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count / 2
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                continue
            }
            if line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }), line.count >= 3 {
                flushParagraph()
                blocks.append(.rule)
                continue
            }
            if let hashes = line.firstIndex(where: { $0 != "#" }), line.hasPrefix("#"),
               line[hashes] == " " {
                flushParagraph()
                let level = line.distance(from: line.startIndex, to: hashes)
                blocks.append(.heading(level: min(level, 6), text: String(line[hashes...]).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if let marker = ["- ", "* ", "• ", "+ "].first(where: { line.hasPrefix($0) }) {
                flushParagraph()
                blocks.append(.bullet(indent: indent, text: String(line.dropFirst(marker.count))))
                continue
            }
            if let dot = line.firstIndex(where: { $0 == "." || $0 == ")" }),
               line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
               line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " {
                flushParagraph()
                let number = String(line[..<dot])
                let text = String(line[line.index(dot, offsetBy: 2)...])
                blocks.append(.numbered(number: number, indent: indent, text: text))
                continue
            }
            paragraph.append(line)
        }
        flushParagraph()
        return blocks
    }
}
