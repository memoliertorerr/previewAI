import Foundation
import Testing
@testable import PreviewAICore

@MainActor
final class MockLoginItemService: LoginItemService {
    var isEnabled = false
    var failure: Error?
    var calls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        calls.append(enabled)
        if let failure { throw failure }
        isEnabled = enabled
    }
}

@MainActor
@Suite struct LaunchAtLoginTests {
    func make() -> (LaunchAtLogin, SettingsStore, MockLoginItemService) {
        let settings = SettingsStore(store: InMemoryKeyValueStore(), secrets: InMemorySecretStore())
        let service = MockLoginItemService()
        return (LaunchAtLogin(settings: settings, service: service), settings, service)
    }

    @Test func togglingRegistersAndUnregisters() {
        let (launch, settings, service) = make()
        #expect(launch.set(true) == nil)
        #expect(settings.launchAtLogin && service.isEnabled)
        #expect(launch.set(false) == nil)
        #expect(!settings.launchAtLogin)
        #expect(service.calls == [true, false])
    }

    @Test func refusalLeavesSettingTruthful() {
        let (launch, settings, service) = make()
        service.failure = NSError(domain: "SMAppService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"])
        let message = launch.set(true)
        #expect(message?.contains("Operation not permitted") == true)
        #expect(!settings.launchAtLogin)
    }

    @Test func syncFollowsTheSystem() {
        let (launch, settings, service) = make()
        settings.launchAtLogin = true
        service.isEnabled = false  // user removed it in System Settings
        launch.syncFromSystem()
        #expect(!settings.launchAtLogin)
    }
}

@MainActor
@Suite struct IdleMemoryTests {
    @Test func closedSessionIsReleasedWithItsTask() async throws {
        weak var weakSession: SummarySession?
        let provider = ScriptedProvider(chunks: Array(repeating: "word ", count: 50), delay: .milliseconds(50))
        do {
            let session = SummarySession()
            weakSession = session
            session.summarize(url: TestSupport.fixture("sample.md"), provider: provider, length: .standard)
            try await Task.sleep(for: .milliseconds(150))
            session.close()
            #expect(session.state == .idle)
            #expect(session.providerLabel.isEmpty)
        }
        // The running task held the session only weakly; once cancelled, nothing keeps it alive.
        let deadline = ContinuousClock.now + .seconds(2)
        while weakSession != nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(weakSession == nil)
    }
}

@Suite struct ErrorCopyTests {
    static let providerErrors: [ProviderError] = [
        .notConfigured("Add a key."), .unauthorized, .rateLimited, .refused, .http(500, "boom"), .http(0, ""),
        .network("Couldn't reach X."), .process("Codex: failed."), .unavailable("Not available."), .emptyResponse,
        .contextTooLong,
    ]
    static let documentErrors: [DocumentError] = [.unsupported("a.png"), .noText, .tooLarge, .unreadable("b.pdf")]

    @Test func everyErrorReadsLikeAShortSentence() {
        let messages = Self.providerErrors.map(\.localizedDescription) + Self.documentErrors.map(\.localizedDescription)
        for message in messages {
            #expect(!message.isEmpty)
            #expect(message.count <= 200, "too long: \(message)")
            #expect(message.first?.isUppercase == true || message.first == "“", "should start like a sentence: \(message)")
            #expect([".", "”", ")"].contains(message.last.map(String.init) ?? ""), "should end with punctuation: \(message)")
            #expect(!message.contains("Error Domain"), "raw NSError text: \(message)")
        }
    }
}
