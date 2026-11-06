import Foundation
import Testing
@testable import PreviewAICore

@MainActor
@Suite struct SummarySessionTests {
    let file = TestSupport.fixture("sample.md")

    @Test func streamsThroughStatesInOrder() async {
        let session = SummarySession()
        var seen: [SummarySession.State] = []
        session.stateDidChange = { seen.append($0) }
        let provider = ScriptedProvider(chunks: ["**TL;DR** ", "three ", "features"])

        session.summarize(url: file, provider: provider, length: .brief)
        await session.waitUntilSettled()

        guard case .finished(let info, let text) = session.state else {
            Issue.record("expected finished, got \(session.state)")
            return
        }
        #expect(text == "**TL;DR** three features")
        #expect(info.kind == .markdown)
        #expect(info.truncationNote == nil)

        // loading (from URL), loading (after extraction), then partial streams, then finished.
        guard case .loading = seen.first else { Issue.record("first state was \(String(describing: seen.first))"); return }
        let partials = seen.compactMap { state -> String? in
            if case .streaming(_, let text) = state { return text }
            return nil
        }
        #expect(partials == ["**TL;DR** ", "**TL;DR** three ", "**TL;DR** three features"])
        #expect(provider.calls.count == 1)
        #expect(provider.calls[0].user.contains("Quarterly Review"))
    }

    @Test func providerErrorFails() async {
        let session = SummarySession()
        session.summarize(url: file, provider: ScriptedProvider(chunks: ["partial"], failure: .unauthorized), length: .standard)
        await session.waitUntilSettled()
        #expect(session.state == .failed(failedInfo(), ProviderError.unauthorized.localizedDescription))
    }

    @Test func unavailableProviderFailsWithReason() async {
        let session = SummarySession()
        let provider = ScriptedProvider(chunks: ["x"], availability: .unavailable("Apple Intelligence is turned off."))
        session.summarize(url: file, provider: provider, length: .standard)
        await session.waitUntilSettled()
        guard case .failed(_, let message) = session.state else { Issue.record("not failed"); return }
        #expect(message == "Apple Intelligence is turned off.")
        #expect(provider.calls.isEmpty)
    }

    @Test func documentErrorFails() async throws {
        let png = try TestSupport.scratch().appendingPathComponent("x.png")
        try Data([1, 2, 3]).write(to: png)
        let session = SummarySession()
        session.summarize(url: png, provider: ScriptedProvider(chunks: ["x"]), length: .standard)
        await session.waitUntilSettled()
        guard case .failed(_, let message) = session.state else { Issue.record("not failed"); return }
        #expect(message == DocumentError.unsupported("x.png").localizedDescription)
    }

    @Test func emptyResponseFails() async {
        let session = SummarySession()
        session.summarize(url: file, provider: ScriptedProvider(chunks: ["  ", "\n"]), length: .standard)
        await session.waitUntilSettled()
        guard case .failed(_, let message) = session.state else { Issue.record("not failed"); return }
        #expect(message == ProviderError.emptyResponse.localizedDescription)
    }

    @Test func cancelStopsSlowStream() async throws {
        let session = SummarySession()
        let provider = ScriptedProvider(chunks: ["a", "b", "c", "d"], delay: .milliseconds(200))
        // Cancel deterministically on the first streamed chunk, not after a fixed sleep.
        session.stateDidChange = { [weak session] state in
            if case .streaming = state { session?.cancel() }
        }
        session.summarize(url: file, provider: provider, length: .standard)
        await session.waitUntilSettled()
        #expect(session.state == .idle)
        // The provider's stream must be torn down well before it could finish on its own (~800 ms).
        let deadline = ContinuousClock.now + .milliseconds(400)
        while provider.terminations == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(provider.terminations == 1)
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.state == .idle)
    }

    @Test func secondRequestIsServedFromCache() async {
        let cache = SummaryCache()
        let session = SummarySession(cache: cache)
        let provider = ScriptedProvider(chunks: ["cached summary"])

        session.summarize(url: file, provider: provider, length: .standard)
        await session.waitUntilSettled()
        session.summarize(url: file, provider: provider, length: .standard)
        await session.waitUntilSettled()

        #expect(provider.calls.count == 1)
        guard case .finished(_, let text) = session.state else { Issue.record("not finished"); return }
        #expect(text == "cached summary")

        // A different length is a different cache entry.
        session.summarize(url: file, provider: provider, length: .detailed)
        await session.waitUntilSettled()
        #expect(provider.calls.count == 2)

        // Regenerate bypasses the cache.
        session.regenerate()
        await session.waitUntilSettled()
        #expect(provider.calls.count == 3)
    }

    @Test func truncationNoteSurfaces() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("long.txt")
        try String(repeating: "lorem ipsum ", count: 1_000).write(to: url, atomically: true, encoding: .utf8)
        let session = SummarySession()
        let provider = ScriptedProvider(inputBudget: 1_200, chunks: ["ok"])
        session.summarize(url: url, provider: provider, length: .brief)
        await session.waitUntilSettled()
        guard case .finished(let info, _) = session.state else { Issue.record("not finished"); return }
        #expect(info.truncationNote?.hasPrefix("Summarized the first 10%") == true)
        #expect(provider.calls[0].user.contains("Only the first 10%"))
    }

    @Test func contextOverflowRetriesOnceWithLessText() async throws {
        let url = try TestSupport.scratch().appendingPathComponent("cjk.txt")
        try String(repeating: "漢字かな交じり文 ", count: 600).write(to: url, atomically: true, encoding: .utf8)
        let session = SummarySession()
        // Budget says 5 400 chars fit, but the "model" only takes ~2 500 (dense script).
        let provider = ScriptedProvider(inputBudget: 5_400, chunks: ["ok"], maxPromptCharacters: 2_500)
        session.summarize(url: url, provider: provider, length: .brief)
        await session.waitUntilSettled()
        guard case .finished(let info, let text) = session.state else { Issue.record("\(session.state)"); return }
        #expect(text == "ok")
        #expect(info.truncationNote != nil)
        #expect(provider.calls.count == 2)
        #expect(!session.failureNeedsSettings)
    }

    @Test func contextOverflowGivesUpAfterOneRetry() async throws {
        let session = SummarySession()
        let provider = ScriptedProvider(chunks: ["ok"], maxPromptCharacters: 10)
        session.summarize(url: TestSupport.fixture("sample.md"), provider: provider, length: .brief)
        await session.waitUntilSettled()
        guard case .failed(_, let message) = session.state else { Issue.record("\(session.state)"); return }
        #expect(message == ProviderError.contextTooLong.localizedDescription)
        #expect(provider.calls.count == 2)
        #expect(!session.failureNeedsSettings)
    }

    @Test func closeForgetsLastRequest() async {
        let session = SummarySession()
        let provider = ScriptedProvider(chunks: ["x"])
        session.summarize(url: file, provider: provider, length: .standard)
        await session.waitUntilSettled()
        session.close()
        #expect(session.state == .idle)
        session.regenerate()
        #expect(session.state == .idle)
        #expect(provider.calls.count == 1)
    }

    @Test func showMessageFailsWithoutDocument() {
        let session = SummarySession()
        session.showMessage("Select a document in Finder first")
        #expect(session.state == .failed(nil, "Select a document in Finder first"))
    }

    private func failedInfo() -> DocumentInfo {
        var info = DocumentInfo(url: file)
        info.kind = .markdown
        return info
    }
}

@MainActor
@Suite struct SummaryCacheTests {
    @Test func evictsLeastRecentlyUsed() {
        let cache = SummaryCache(capacity: 20)
        let keys = (0..<21).map { i in
            SummaryCache.Key(url: URL(fileURLWithPath: "/nonexistent/\(i).md"), provider: .anthropic, model: "m", length: .standard)
        }
        for (i, key) in keys.prefix(20).enumerated() { cache.store("s\(i)", for: key) }
        #expect(cache.value(for: keys[0]) == "s0")  // touch 0 so 1 becomes the oldest
        cache.store("s20", for: keys[20])
        #expect(cache.count == 20)
        #expect(cache.value(for: keys[1]) == nil)
        #expect(cache.value(for: keys[0]) == "s0")
        #expect(cache.value(for: keys[20]) == "s20")
    }

    @Test func keyIncludesProviderAndModel() {
        let url = URL(fileURLWithPath: "/nonexistent/a.md")
        let a = SummaryCache.Key(url: url, provider: .anthropic, model: "m1", length: .brief)
        let b = SummaryCache.Key(url: url, provider: .anthropic, model: "m2", length: .brief)
        let c = SummaryCache.Key(url: url, provider: .openAICompatible, model: "m1", length: .brief)
        #expect(Set([a, b, c]).count == 3)
    }
}
