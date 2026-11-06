import Foundation
import Testing
@testable import PreviewAICore

@Suite struct OpenAICompatibleProviderTests {
    let request = SummaryRequest(system: "SYSTEM", user: "USER", maxOutputTokens: 1_200)

    static func chunk(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"id":"c1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"\#(escaped)"},"finish_reason":null}]}"#
    }

    static let happy: [Data] = [
        Data("data: {\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"}}]}\n\n".utf8),
        Data("data: \(chunk("**TL;DR** "))\n\n".utf8),
        Data("data: \(chunk("Local works."))\n\n".utf8),
        Data("data: [DONE]\n\n".utf8),
        Data("data: \(chunk(" IGNORED"))\n\n".utf8),
    ]

    func make(_ response: StubURLProtocol.Response, preset: OpenAICompatiblePreset = .ollama, model: String = "llama3.2", key: String? = nil) -> (OpenAICompatibleProvider, URL) {
        let base = StubURLProtocol.register(response).appendingPathComponent("v1")
        var config = OpenAICompatibleConfig()
        config.preset = preset
        config.baseURL = base.absoluteString
        config.model = model
        return (OpenAICompatibleProvider(config: config, apiKey: key, http: StubURLProtocol.client()), base)
    }

    @Test func presetsResolveToDocumentedURLs() {
        #expect(OpenAICompatiblePreset.openAI.defaultBaseURL == "https://api.openai.com/v1")
        #expect(OpenAICompatiblePreset.ollama.defaultBaseURL == "http://localhost:11434/v1")
        #expect(OpenAICompatiblePreset.lmStudio.defaultBaseURL == "http://localhost:1234/v1")
        #expect(OpenAICompatiblePreset.custom.defaultBaseURL == "")
    }

    @Test func localRequestHasNoAuthAndACap() async throws {
        let (provider, base) = make(.init(chunks: Self.happy))
        _ = await collect(provider.stream(request))
        let recorded = try #require(StubURLProtocol.requests(for: base).first)
        #expect(recorded.request.httpMethod == "POST")
        #expect(recorded.request.url?.path == "/v1/chat/completions")
        #expect(recorded.header("Authorization") == nil)
        let json = recorded.json
        #expect(json["model"] as? String == "llama3.2")
        #expect(json["stream"] as? Bool == true)
        #expect(json["max_tokens"] as? Int == 1_200)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "system", "content": "SYSTEM"], ["role": "user", "content": "USER"]])
    }

    @Test func openAIRequestSendsBearerAndNoTokenCap() async throws {
        let (provider, base) = make(.init(chunks: Self.happy), preset: .openAI, model: "some-model", key: "sk-openai")
        _ = await collect(provider.stream(request))
        let recorded = try #require(StubURLProtocol.requests(for: base).first)
        #expect(recorded.header("Authorization") == "Bearer sk-openai")
        #expect(recorded.json["max_tokens"] == nil)
        #expect(recorded.json["max_completion_tokens"] == nil)
    }

    @Test func streamsDeltasAndStopsAtDone() async {
        let (provider, _) = make(.init(chunks: Self.happy))
        let result = await collect(provider.stream(request))
        #expect(result.error == nil)
        #expect(result.text == "**TL;DR** Local works.")
    }

    @Test func toleratesChunkSplitsAndMissingDone() async {
        let joined = Self.happy.prefix(3).reduce(Data(), +)
        let chunks = stride(from: 0, to: joined.count, by: 3).map { joined.subdata(in: $0..<min($0 + 3, joined.count)) }
        let (provider, _) = make(.init(chunks: chunks))
        #expect(await collect(provider.stream(request)).text == "**TL;DR** Local works.")
    }

    @Test func inStreamErrorAndContentFilterThrow() async {
        let (errored, _) = make(.init(chunks: [Data("data: {\"error\":{\"message\":\"model not loaded\"}}\n\n".utf8)]))
        #expect(await collect(errored.stream(request)).error as? ProviderError == .http(0, "model not loaded"))
        let filtered = Data("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"content_filter\"}]}\n\n".utf8)
        let (refused, _) = make(.init(chunks: [filtered]))
        #expect(await collect(refused.stream(request)).error as? ProviderError == .refused)
    }

    @Test func httpErrorsMap() async {
        let (unauthorized, _) = make(.init(status: 401, chunks: [Data(#"{"error":{"message":"bad key"}}"#.utf8)]), preset: .openAI, key: "x")
        #expect(await collect(unauthorized.stream(request)).error as? ProviderError == .unauthorized)
        let (missing, _) = make(.init(status: 404, chunks: [Data(#"{"error":"model 'nope' not found"}"#.utf8)]))
        #expect(await collect(missing.stream(request)).error as? ProviderError == .http(404, "model 'nope' not found"))
    }

    @Test func connectionRefusedOnLocalPresetSaysIsItRunning() async {
        let (provider, base) = make(.init(error: URLError(.cannotConnectToHost)))
        let error = await collect(provider.stream(request)).error as? ProviderError
        #expect(error == .network("Couldn't reach Ollama at \(base.host!) — is it running?"))

        let local = OpenAICompatibleProvider(config: OpenAICompatibleConfig.preset(.ollama, model: "m"), apiKey: nil)
        #expect(local.networkError(URLError(.cannotConnectToHost)) == .network("Couldn't reach Ollama at localhost:11434 — is it running?"))
    }

    @Test func listModelsParsesAndSorts() async throws {
        let body = #"{"object":"list","data":[{"id":"qwen2.5"},{"id":"llama3.2"},{"id":"gemma3"}]}"#
        let (provider, base) = make(.init(headers: ["content-type": "application/json"], chunks: [Data(body.utf8)]))
        #expect(try await provider.listModels() == ["gemma3", "llama3.2", "qwen2.5"])
        #expect(StubURLProtocol.requests(for: base).first?.request.url?.path == "/v1/models")
    }

    @Test func availabilityExplainsWhatsMissing() async {
        let noKey = OpenAICompatibleProvider(config: .preset(.openAI, model: "m"), apiKey: nil)
        #expect(await noKey.availability() == .unavailable("Add your OpenAI API key in PreviewAI Settings."))
        let noModel = OpenAICompatibleProvider(config: .preset(.ollama, model: ""), apiKey: nil)
        #expect(await noModel.availability() == .unavailable("Choose a model for Ollama in PreviewAI Settings."))
        let noURL = OpenAICompatibleProvider(config: .preset(.custom, model: "m"), apiKey: nil)
        guard case .unavailable(let urlReason) = await noURL.availability() else { Issue.record("should be unavailable"); return }
        #expect(urlReason.contains("server URL"))
        let ready = OpenAICompatibleProvider(config: .preset(.lmStudio, model: "m"), apiKey: nil)
        #expect(await ready.availability() == .ready)
    }

    @Test func budgetsDependOnPreset() {
        #expect(OpenAICompatibleProvider(config: .preset(.openAI, model: "m"), apiKey: "k").inputBudget == 400_000)
        #expect(OpenAICompatibleProvider(config: .preset(.ollama, model: "m"), apiKey: nil).inputBudget == 24_000)
    }
}

extension OpenAICompatibleConfig {
    static func preset(_ preset: OpenAICompatiblePreset, model: String) -> OpenAICompatibleConfig {
        var config = OpenAICompatibleConfig()
        config.preset = preset
        config.model = model
        return config
    }
}
