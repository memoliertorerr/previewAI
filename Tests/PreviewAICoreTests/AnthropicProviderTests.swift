import Foundation
import Testing
@testable import PreviewAICore

@Suite struct AnthropicProviderTests {
    let request = SummaryRequest(system: "SYSTEM", user: "USER", maxOutputTokens: 1_200)

    func provider(_ response: StubURLProtocol.Response, model: String = "claude-opus-5-5", key: String? = "sk-test") -> (AnthropicProvider, URL) {
        let base = StubURLProtocol.register(response)
        return (AnthropicProvider(apiKey: key, model: model, baseURL: base, http: StubURLProtocol.client()), base)
    }

    static let happyStream = StubURLProtocol.sse([
        ("message_start", #"{"type":"message_start","message":{"id":"msg_1","type":"message"}}"#),
        ("content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#),
        ("content_block_delta", #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"secret"}}"#),
        ("content_block_stop", #"{"type":"content_block_stop","index":0}"#),
        ("content_block_start", #"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#),
        ("content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"**TL;DR** "}}"#),
        ("ping", #"{"type":"ping"}"#),
        ("content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Revenue grew."}}"#),
        ("content_block_stop", #"{"type":"content_block_stop","index":1}"#),
        ("message_delta", #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":12}}"#),
        ("message_stop", #"{"type":"message_stop"}"#),
    ])

    @Test func sendsTheDocumentedRequest() async throws {
        let (provider, base) = provider(.init(chunks: Self.happyStream))
        _ = await collect(provider.stream(request))
        let recorded = try #require(StubURLProtocol.requests(for: base).first)

        #expect(recorded.request.httpMethod == "POST")
        #expect(recorded.request.url?.path == "/v1/messages")
        #expect(recorded.header("x-api-key") == "sk-test")
        #expect(recorded.header("anthropic-version") == "2026-10-21")
        #expect(recorded.header("content-type") == "application/json")

        let json = recorded.json
        #expect(json["model"] as? String == "claude-opus-5-5")
        #expect(json["max_tokens"] as? Int == 16_000)
        #expect(json["stream"] as? Bool == true)
        #expect(json["system"] as? String == "SYSTEM")
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")
        #expect(messages[0]["content"] as? String == "USER")
        #expect((json["output_config"] as? [String: Any])?["effort"] as? String == "low")
        for banned in ["temperature", "top_p", "top_k", "thinking"] {
            #expect(json[banned] == nil, "\(banned) must not be sent")
        }
    }

    @Test func opusAndSonnetGetServerFallbackHaikuDoesNot() async throws {
        for model in ["claude-opus-5-5", "claude-sonnet-5-5"] {
            let (provider, base) = provider(.init(chunks: Self.happyStream), model: model)
            _ = await collect(provider.stream(request))
            let recorded = try #require(StubURLProtocol.requests(for: base).first)
            #expect(recorded.json["fallbacks"] as? String == "default", "\(model)")
            #expect(recorded.header("anthropic-beta") == "server-side-fallback-2026-07-01", "\(model)")
        }
        let (haiku, base) = provider(.init(chunks: Self.happyStream), model: "claude-haiku-5-5")
        _ = await collect(haiku.stream(request))
        let recorded = try #require(StubURLProtocol.requests(for: base).first)
        #expect(recorded.json["fallbacks"] == nil)
        #expect(recorded.header("anthropic-beta") == nil)
    }

    @Test func yieldsOnlyTextDeltasInOrder() async {
        let (provider, _) = provider(.init(chunks: Self.happyStream))
        let result = await collect(provider.stream(request))
        #expect(result.error == nil)
        #expect(result.text == "**TL;DR** Revenue grew.")
    }

    @Test func eventsSplitAcrossChunksStillParse() async {
        let joined = Self.happyStream.reduce(Data(), +)
        let chunks = stride(from: 0, to: joined.count, by: 5).map { joined.subdata(in: $0..<min($0 + 5, joined.count)) }
        let (provider, _) = provider(.init(chunks: chunks))
        #expect(await collect(provider.stream(request)).text == "**TL;DR** Revenue grew.")
    }

    @Test func refusalThrowsRefused() async {
        let stream = StubURLProtocol.sse([
            ("content_block_delta", #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"I"}}"#),
            ("message_delta", #"{"type":"message_delta","delta":{"stop_reason":"refusal"}}"#),
        ])
        let (provider, _) = provider(.init(chunks: stream))
        #expect(await collect(provider.stream(request)).error as? ProviderError == .refused)
    }

    @Test func streamErrorEventThrows() async {
        let stream = StubURLProtocol.sse([
            ("error", #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#),
        ])
        let (provider, _) = provider(.init(chunks: stream))
        let error = await collect(provider.stream(request)).error as? ProviderError
        #expect(error == .network("Anthropic is overloaded right now — try again in a moment."))
    }

    @Test(arguments: [
        (401, #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#, ProviderError.unauthorized),
        (429, #"{"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}"#, ProviderError.rateLimited),
        (400, #"{"type":"error","error":{"type":"invalid_request_error","message":"model: not found"}}"#, ProviderError.http(400, "model: not found")),
    ])
    func httpErrorsMap(status: Int, body: String, expected: ProviderError) async {
        let (provider, _) = provider(.init(status: status, headers: ["content-type": "application/json"], chunks: [Data(body.utf8)]))
        #expect(await collect(provider.stream(request)).error as? ProviderError == expected)
    }

    @Test func networkErrorMapsToReadableMessage() async {
        let (provider, _) = provider(.init(error: URLError(.notConnectedToInternet)))
        guard case .network(let message)? = await collect(provider.stream(request)).error as? ProviderError else {
            Issue.record("expected network error"); return
        }
        #expect(message.hasPrefix("Couldn't reach Anthropic"))
    }

    @Test func missingKeyIsUnavailable() async {
        let (provider, _) = provider(.init(), key: nil)
        guard case .unavailable(let reason) = await provider.availability() else { Issue.record("should be unavailable"); return }
        #expect(reason.contains("Anthropic API key"))
        let (keyed, _) = self.provider(.init(), key: "sk")
        #expect(await keyed.availability() == .ready)
    }

    @MainActor
    @Test func registryBuildsAnthropicFromSettings() throws {
        let settings = SettingsStore(store: InMemoryKeyValueStore(), secrets: InMemorySecretStore())
        settings.selectedProvider = .anthropic
        settings.anthropic.model = "claude-haiku-5-5"
        try settings.setAPIKey("sk-x", for: .anthropic)
        let provider = ProviderRegistry(settings: settings).current
        #expect(provider is AnthropicProvider)
        #expect(provider.modelName == "claude-haiku-5-5")
    }
}
