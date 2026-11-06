import Foundation
import Testing
@testable import PreviewAICore

@Suite struct PromptBuilderTests {
    let doc = DocumentContent(
        url: URL(fileURLWithPath: "/docs/Annual Report.pdf"),
        kind: .pdf,
        text: "Revenue grew 12%.",
        pageCount: 4
    )

    @Test(arguments: SummaryLength.allCases)
    func requestContainsEssentials(length: SummaryLength) {
        let request = PromptBuilder.request(for: doc, length: length)
        #expect(request.system == PromptBuilder.system)
        #expect(request.user.contains("Title: Annual Report"))
        #expect(request.user.contains("Pages: 4"))
        #expect(request.user.contains("<document>\nRevenue grew 12%.\n</document>"))
        #expect(request.user.contains(length.instruction))
        #expect(request.maxOutputTokens == length.maxOutputTokens)
        #expect(!request.user.contains("Only the first"))
    }

    @Test func truncatedDocumentsAreFlagged() {
        let long = DocumentContent(url: URL(fileURLWithPath: "/x/long.txt"), kind: .plainText,
                                   text: String(repeating: "word ", count: 2_000))
        let request = PromptBuilder.request(for: long.budgeted(maxCharacters: 2_500), length: .brief)
        #expect(request.user.contains("Only the first 25% of the document is included"))
    }

    @Test func lengthsDiffer() {
        let instructions = Set(SummaryLength.allCases.map(\.instruction))
        #expect(instructions.count == SummaryLength.allCases.count)
    }
}
