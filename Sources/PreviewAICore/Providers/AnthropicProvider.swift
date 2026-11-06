import Foundation

/// Claude via the Anthropic Messages API (raw HTTP + SSE — there is no Swift SDK).
public struct AnthropicProvider: SummaryProvider {
    public let id = ProviderID.anthropic
    public let displayName = "Claude"
    public let modelName: String
    public let inputBudget = 400_000

    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    /// Models that accept `fallbacks: "default"` on the Claude API. Haiku has no server-side
    /// fallback, so it's not listed.
    static let modelsWithServerFallback: Set<String> = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-opus-5", "claude-fable-5-1"]
    /// Thinking can't be disabled on current models and counts toward `max_tokens`, so leave
    /// generous headroom; streaming means no timeout risk.
    static let maxTokens = 16_000

    private let apiKey: String?
    private let baseURL: URL
    private let http: HTTPClient

    public init(apiKey: String?, model: String, baseURL: URL = URL(string: "https://api.anthropic.com")!, http: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.modelName = model.isEmpty ? AnthropicConfig().model : model
        self.baseURL = baseURL
        self.http = http
    }

    public func availability() async -> ProviderAvailability {
        guard let apiKey, !apiKey.isEmpty else {
            return .unavailable("Add your Anthropic API key in PreviewAI Settings to use Claude.")
        }
        return .ready
    }

    func urlRequest(for request: SummaryRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/messages"), timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey ?? "", forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": modelName,
            "max_tokens": max(request.maxOutputTokens, Self.maxTokens),
            "stream": true,
            "system": request.system,
            "messages": [["role": "user", "content": request.user]],
            // Summaries don't need deep reasoning; low effort keeps them fast.
            "output_config": ["effort": "low"],
        ]
        if Self.modelsWithServerFallback.contains(modelName) {
            body["fallbacks"] = "default"
            urlRequest.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bytes = try await http.stream(try urlRequest(for: request))
                    var parser = SSEParser()
                    var buffer: [UInt8] = []
                    for try await byte in bytes {
                        buffer.append(byte)
                        guard byte == UInt8(ascii: "\n") else { continue }
                        for event in parser.feed(buffer) {
                            if let text = try Self.handle(event) { continuation.yield(text) }
                        }
                        buffer.removeAll(keepingCapacity: true)
                    }
                    for event in parser.feed(buffer) + parser.finish() {
                        if let text = try Self.handle(event) { continuation.yield(text) }
                    }
                    continuation.finish()
                } catch let failure as HTTPFailure {
                    continuation.finish(throwing: Self.map(failure))
                } catch let error as URLError where error.code != .cancelled {
                    continuation.finish(throwing: ProviderError.network("Couldn't reach Anthropic: \(error.localizedDescription)"))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Returns text for `text_delta` events; throws for refusals and stream errors.
    static func handle(_ event: SSEEvent) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any] else { return nil }
        switch json["type"] as? String {
        case "content_block_delta":
            guard let delta = json["delta"] as? [String: Any], delta["type"] as? String == "text_delta" else { return nil }
            return delta["text"] as? String
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                throw ProviderError.refused
            }
            return nil
        case "error":
            let error = json["error"] as? [String: Any]
            throw map(type: error?["type"] as? String, status: 0, message: error?["message"] as? String ?? "")
        default:
            return nil
        }
    }

    static func map(_ failure: HTTPFailure) -> ProviderError {
        map(type: failure.errorType, status: failure.status, message: failure.message)
    }

    static func map(type: String?, status: Int, message: String) -> ProviderError {
        switch (type, status) {
        case ("authentication_error", _), (_, 401): .unauthorized
        case ("rate_limit_error", _), (_, 429): .rateLimited
        case ("overloaded_error", _), (_, 529): .network("Anthropic is overloaded right now — try again in a moment.")
        default: .http(status, message)
        }
    }
}
