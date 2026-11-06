import Foundation
import Testing
@testable import PreviewAICore

@Suite struct SSEParserTests {
    let stream = """
    : keep-alive comment\r
    event: content_block_delta\r
    data: {"a":1}\r
    \r
    data: line one
    data: line two

    event: ping
    data: {}

    """

    @Test func parsesCRLFCommentsAndMultilineData() {
        var parser = SSEParser()
        let events = parser.feed(Array(stream.utf8)) + parser.finish()
        #expect(events == [
            SSEEvent(event: "content_block_delta", data: "{\"a\":1}"),
            SSEEvent(event: "message", data: "line one\nline two"),
            SSEEvent(event: "ping", data: "{}"),
        ])
    }

    @Test(arguments: [1, 2, 3, 7, 64])
    func handlesArbitraryChunking(chunkSize: Int) {
        var parser = SSEParser()
        var events: [SSEEvent] = []
        let bytes = Array(stream.utf8)
        for start in stride(from: 0, to: bytes.count, by: chunkSize) {
            events += parser.feed(bytes[start..<min(start + chunkSize, bytes.count)])
        }
        events += parser.finish()
        #expect(events.count == 3)
        #expect(events[1].data == "line one\nline two")
    }

    @Test func handlesMultibyteCharactersSplitAcrossChunks() {
        var parser = SSEParser()
        let bytes = Array("data: héllo 漢字\n\n".utf8)
        var events: [SSEEvent] = []
        for byte in bytes { events += parser.feed([byte]) }
        #expect(events == [SSEEvent(event: "message", data: "héllo 漢字")])
    }

    @Test func flushesUnterminatedFinalEvent() {
        var parser = SSEParser()
        var events = parser.feed(Array("data: [DONE]".utf8))
        #expect(events.isEmpty)
        events = parser.finish()
        #expect(events == [SSEEvent(event: "message", data: "[DONE]")])
    }
}
