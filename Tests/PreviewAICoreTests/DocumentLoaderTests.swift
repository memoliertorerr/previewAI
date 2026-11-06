import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import PreviewAICore

@Suite struct DocumentLoaderTests {
    let loader = DocumentLoader()

    @Test func markdownLoadsVerbatim() async throws {
        let url = TestSupport.fixture("sample.md")
        let doc = try await loader.load(url)
        #expect(doc.kind == .markdown)
        #expect(doc.title == "sample")
        let expected = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(doc.text == expected)
        #expect(doc.pageCount == nil)
        #expect(!doc.isTruncated)
    }

    @Test func pdfLoadsEveryPage() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("three-pages.pdf")
        try PDFFixture.write(pages: ["Alpha page text", "Bravo page text", "Charlie page text"], to: url)
        let doc = try await loader.load(url)
        #expect(doc.kind == .pdf)
        #expect(doc.pageCount == 3)
        for word in ["Alpha", "Bravo", "Charlie"] {
            #expect(doc.text.contains(word))
        }
    }

    @Test func pdfWithoutTextThrowsNoText() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("blank.pdf")
        try PDFFixture.write(pages: ["", ""], to: url)
        await #expect(throws: DocumentError.noText) {
            try await loader.load(url)
        }
    }

    @Test func rtfLoadsAsPlainText() async throws {
        let doc = try await loader.load(TestSupport.fixture("sample.rtf"))
        #expect(doc.kind == .richText)
        #expect(doc.text.contains("the bridge opened in 1932"))
        #expect(!doc.text.contains("\\rtf"))
    }

    @Test func htmlLoadsAsPlainText() async throws {
        let doc = try await loader.load(TestSupport.fixture("sample.html"))
        #expect(doc.kind == .html)
        #expect(doc.text.contains("dark mode"))
        #expect(!doc.text.contains("<p>"))
    }

    @Test func docxLoadsAsPlainText() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("memo.docx")
        let source = NSAttributedString(string: "Word memo: the budget was approved.")
        let data = try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try data.write(to: url)
        let doc = try await loader.load(url)
        #expect(doc.kind == .word)
        #expect(doc.text.contains("the budget was approved"))
    }

    @Test func unsupportedTypeThrows() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("picture.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        await #expect(throws: DocumentError.unsupported("picture.png")) {
            try await loader.load(url)
        }
    }

    @Test func budgetCutsAtBoundary() {
        // 1 000 words of 9 chars + space = 10 000 characters.
        let text = String(repeating: "abcdefghi ", count: 1_000)
        let doc = DocumentContent(url: URL(fileURLWithPath: "/x/long.txt"), kind: .plainText, text: text)
        let cut = doc.budgeted(maxCharacters: 4_000)
        #expect(cut.isTruncated)
        #expect(cut.text.count <= 4_000)
        #expect(cut.text.count > 3_900)
        #expect(cut.text.hasSuffix("abcdefghi"))
        #expect(abs(cut.fractionIncluded - 0.4) < 0.01)
        #expect(cut.originalLength == text.count)
    }

    @Test func budgetPrefersParagraphBreak() {
        let text = String(repeating: "a", count: 900) + "\n\n" + String(repeating: "b ", count: 200)
        let doc = DocumentContent(url: URL(fileURLWithPath: "/x/p.txt"), kind: .plainText, text: text)
        let cut = doc.budgeted(maxCharacters: 1_000)
        #expect(cut.text == String(repeating: "a", count: 900))
    }

    @Test func budgetLeavesShortDocumentsAlone() {
        let doc = DocumentContent(url: URL(fileURLWithPath: "/x/s.txt"), kind: .plainText, text: "short")
        #expect(doc.budgeted(maxCharacters: 100) == doc)
        #expect(doc.fractionIncluded == 1)
    }

    @Test func errorsHaveMessages() {
        let errors: [DocumentError] = [.unsupported("a.png"), .noText, .tooLarge, .unreadable("b.pdf")]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}

/// Writes simple multi-page PDFs with real (extractable) text.
enum PDFFixture {
    static func write(pages: [String], to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw DocumentError.unreadable(url.lastPathComponent)
        }
        let font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
        for page in pages {
            context.beginPDFPage(nil)
            if !page.isEmpty {
                let attributed = NSAttributedString(string: page, attributes: [.init(kCTFontAttributeName as String): font])
                let line = CTLineCreateWithAttributedString(attributed)
                context.textPosition = CGPoint(x: 72, y: 700)
                CTLineDraw(line, context)
            }
            context.endPDFPage()
        }
        context.closePDF()
    }
}
