import Foundation
import Testing
@testable import PreviewAICore

@Suite struct AppleIntelligenceProviderTests {
    @Test func budgetFitsOnDeviceContext() {
        let budget = AppleIntelligenceProvider.budget(contextSize: 4_096)
        #expect(budget <= 9_000)
        #expect(budget >= 5_000)
        // Prompt (≈ budget/3 tokens) + reserved tokens must fit the 4 096-token window.
        #expect(budget / AppleIntelligenceProvider.charactersPerToken + AppleIntelligenceProvider.reservedTokens <= 4_096)
        #expect(AppleIntelligenceProvider.maxOutputTokens < AppleIntelligenceProvider.reservedTokens)
    }

    @Test func budgetScalesWithLargerContexts() {
        #expect(AppleIntelligenceProvider.budget(contextSize: 16_384) > AppleIntelligenceProvider.budget(contextSize: 4_096))
        #expect(AppleIntelligenceProvider.budget(contextSize: 100) == 2_000)
    }

    @Test func liveBudgetIsSane() {
        let budget = AppleIntelligenceProvider().inputBudget
        #expect(budget >= 2_000)
    }

    @Test func availabilityHasReadableReason() async {
        // The dev machine and CI may or may not have Apple Intelligence; either way the result
        // must be ready or carry a human sentence.
        switch await AppleIntelligenceProvider().availability() {
        case .ready: break
        case .unavailable(let reason): #expect(reason.count > 20)
        }
    }

    @Test func deltaTrackerTurnsSnapshotsIntoDeltas() {
        var tracker = DeltaTracker()
        #expect(tracker.next("Hel") == "Hel")
        #expect(tracker.next("Hello") == "lo")
        #expect(tracker.next("Hello") == "")
        #expect(tracker.next("Hello, world") == ", world")
        // A revision of already-sent text never re-emits it; only text past what was sent.
        #expect(tracker.next("Hello, there friend") == " friend")
        #expect(tracker.next("Hi") == "")
    }
}

@MainActor
@Suite struct ProviderRegistryTests {
    @Test func defaultsToAppleIntelligence() {
        #expect(ProviderRegistry().current.id == .appleIntelligence)
    }

    @Test func unconfiguredProvidersExplainThemselves() async {
        let registry = ProviderRegistry(selected: .anthropic)
        let provider = registry.current
        #expect(provider.id == .anthropic)
        #expect(await provider.availability() == .unavailable("Anthropic API isn't set up yet."))
    }

    @Test func providerFailuresOfferSettingsButDocumentFailuresDont() async throws {
        let session = SummarySession()
        session.summarize(url: TestSupport.fixture("sample.md"), provider: UnavailableProvider(id: .anthropic, reason: "Not set up."), length: .brief)
        await session.waitUntilSettled()
        #expect(session.failureNeedsSettings)

        session.summarize(url: TestSupport.fixture("sample.md"), provider: ScriptedProvider(chunks: ["x"], failure: .unauthorized), length: .brief)
        await session.waitUntilSettled()
        #expect(session.failureNeedsSettings)

        let png = try TestSupport.scratch().appendingPathComponent("a.png")
        try Data([0]).write(to: png)
        session.summarize(url: png, provider: ScriptedProvider(chunks: ["x"]), length: .brief)
        await session.waitUntilSettled()
        #expect(!session.failureNeedsSettings)

        session.summarize(url: TestSupport.fixture("sample.md"), provider: ScriptedProvider(chunks: ["x"], failure: .rateLimited), length: .brief)
        await session.waitUntilSettled()
        #expect(!session.failureNeedsSettings)
    }
}
