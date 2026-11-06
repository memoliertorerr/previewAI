import Foundation
import Testing
@testable import PreviewAICore

@Suite struct PanelContentTests {
    let url = URL(fileURLWithPath: "/docs/Report.pdf")

    func info(pages: Int? = 12, note: String? = nil) -> DocumentInfo {
        var info = DocumentInfo(url: url)
        info.pageCount = pages
        info.truncationNote = note
        return info
    }

    @Test func idleIsEmpty() {
        let content = PanelContent(state: .idle)
        #expect(content.title == "PreviewAI")
        #expect(!content.isWorking && !content.canCopy && content.error == nil)
    }

    @Test func loadingShowsTitleAndSpinner() {
        let content = PanelContent(state: .loading(info()))
        #expect(content.title == "Report.pdf")
        #expect(content.subtitle == "PDF · 12 pages")
        #expect(content.isWorking)
        #expect(!content.isStreaming)
        #expect(content.body.isEmpty)
        #expect(!content.canCopy)
    }

    @Test func streamingExposesText() {
        let content = PanelContent(state: .streaming(info(pages: 1), "**TL;DR**"))
        #expect(content.body == "**TL;DR**")
        #expect(content.isWorking && content.isStreaming)
        #expect(content.subtitle == "PDF · 1 page")
        #expect(!content.canCopy)
    }

    @Test func finishedAllowsCopyAndRegenerate() {
        let content = PanelContent(state: .finished(info(), "done"), additionalFiles: 2)
        #expect(content.canCopy && content.canRegenerate)
        #expect(!content.isWorking)
        #expect(content.subtitle == "PDF · 12 pages · +2 more selected")
    }

    @Test func failedExposesMessageAndRetry() {
        let content = PanelContent(state: .failed(info(), "Key rejected"))
        #expect(content.error == "Key rejected")
        #expect(content.canRegenerate)
        #expect(!content.canCopy)
        #expect(PanelContent(state: .failed(nil, "x")).canRegenerate == false)
    }

    @Test func truncationNoteSurfaces() {
        let content = PanelContent(state: .finished(info(note: "Summarized the first 40%"), "x"))
        #expect(content.truncationNote == "Summarized the first 40%")
    }
}

@Suite struct MarkdownBlockTests {
    @Test func parsesSummaryShapes() {
        let markdown = """
        **TL;DR:** Revenue grew.

        ### Highlights
        - First point
        - Second *point*
          - Nested
        1. Step one
        2) Step two

        ---
        Why it matters: growth
        continues.
        """
        #expect(MarkdownBlock.parse(markdown) == [
            .paragraph("**TL;DR:** Revenue grew."),
            .heading(level: 3, text: "Highlights"),
            .bullet(indent: 0, text: "First point"),
            .bullet(indent: 0, text: "Second *point*"),
            .bullet(indent: 1, text: "Nested"),
            .numbered(number: "1", indent: 0, text: "Step one"),
            .numbered(number: "2", indent: 0, text: "Step two"),
            .rule,
            .paragraph("Why it matters: growth continues."),
        ])
    }

    @Test func toleratesPartialStreams() {
        #expect(MarkdownBlock.parse("- Fir") == [.bullet(indent: 0, text: "Fir")])
        #expect(MarkdownBlock.parse("##") == [.paragraph("##")])
        #expect(MarkdownBlock.parse("") == [])
        #expect(MarkdownBlock.parse("#hashtag") == [.paragraph("#hashtag")])
        #expect(MarkdownBlock.parse("2026. A year") == [.numbered(number: "2026", indent: 0, text: "A year")])
    }
}
