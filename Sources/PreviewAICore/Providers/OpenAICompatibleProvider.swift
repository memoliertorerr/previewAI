import Foundation

/// OpenAI's Chat Completions API and everything that speaks it: Ollama, LM Studio, and custom
/// endpoints (OpenRouter, Groq, a self-hosted server…).
public struct OpenAICompatibleProvider: SummaryProvider {
    public let id = ProviderID.openAICompatible
    public let modelName: String
    public let preset: OpenAICompatiblePreset
    private let baseURLString: String
    private let apiKey: String?
    private let http: HTTPClient

    public init(config: OpenAICompatibleConfig, apiKey: String?, http: HTTPClient = .shared) {
        self.preset = config.preset
        self.baseURLString = config.effectiveBaseURL
        self.modelName = config.model.trimmingCharacters(in: .whitespaces)
        self.apiKey = apiKey?.isEmpty == true ? nil : apiKey
        self.http = http
    }

    public var displayName: String { preset.displayName }

    /// Local models usually have small context windows; cloud ones are large.
    public var inputBudget: Int {
        switch preset {
        case .openAI: 400_000
        case .ollama, .lmStudio: 24_000
        case .custom: 100_000
        }
    }

    var baseURL: URL? {
        guard let url = URL(string: baseURLString), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    public func availability() async -> ProviderAvailability {
        if preset.needsAPIKey && apiKey == nil {
            return .unavailable("Add your \(preset.displayName) API key in PreviewAI Settings.")
        }
        guard baseURL != nil else {
            return .unavailable("Set a valid server URL for \(preset.displayName) in PreviewAI Settings.")
        }
        guard !modelName.isEmpty else {
            return .unavailable("Choose a model for \(preset.displayName) in PreviewAI Settings.")
        }
        return .ready
    }

    func authorized(_ request: inout URLRequest) {
        if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
    }

    func urlRequest(for request: SummaryRequest) throws -> URLRequest {
        guard let baseURL else { throw ProviderError.notConfigured("The \(preset.displayName) server URL isn't valid.") }
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorized(&urlRequest)
        var body: [String: Any] = [
            "model": modelName,
            "stream": true,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user],
            ],
        ]
        // OpenAI's reasoning models reject `max_tokens` (and count reasoning against
        // `max_completion_tokens`), so no cap is sent there. Other servers get the usual cap.
        if preset != .openAI {
            body["max_tokens"] = request.maxOutputTokens
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
                    var done = false
                    for try await byte in bytes {
                        buffer.append(byte)
                        guard byte == UInt8(ascii: "\n") else { continue }
                        for event in parser.feed(buffer) where !done {
                            if event.data == "[DONE]" { done = true; break }
                            if let text = try Self.text(from: event) { continuation.yield(text) }
                        }
                        buffer.removeAll(keepingCapacity: true)
                        if done { break }
                    }
                    if !done {
                        for event in parser.feed(buffer) + parser.finish() where event.data != "[DONE]" {
                            if let text = try Self.text(from: event) { continuation.yield(text) }
                        }
                    }
                    continuation.finish()
                } catch let failure as HTTPFailure {
                    continuation.finish(throwing: Self.map(failure))
                } catch let error as URLError where error.code != .cancelled {
                    continuation.finish(throwing: networkError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Model IDs from `GET {base}/models`, sorted — for the Settings picker.
    public func listModels() async throws -> [String] {
        guard let baseURL else { throw ProviderError.notConfigured("The \(preset.displayName) server URL isn't valid.") }
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        authorized(&request)
        do {
            let data = try await http.data(request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = (json?["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
            return models.sorted()
        } catch let failure as HTTPFailure {
            throw Self.map(failure)
        } catch let error as URLError {
            throw networkError(error)
        }
    }

    static func text(from event: SSEEvent) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(event.data.utf8)) as? [String: Any] else { return nil }
        if let error = json["error"] {
            let message = (error as? [String: Any])?["message"] as? String ?? (error as? String) ?? ""
            throw ProviderError.http(0, message)
        }
        let choice = (json["choices"] as? [[String: Any]])?.first
        if choice?["finish_reason"] as? String == "content_filter" { throw ProviderError.refused }
        return (choice?["delta"] as? [String: Any])?["content"] as? String
    }

    static func map(_ failure: HTTPFailure) -> ProviderError {
        switch failure.status {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        default: .http(failure.status, failure.message)
        }
    }

    func networkError(_ error: URLError) -> ProviderError {
        let place = baseURL.map { "\($0.host ?? "")\($0.port.map { ":\($0)" } ?? "")" } ?? baseURLString
        if preset.isLocal, [.cannotConnectToHost, .networkConnectionLost, .timedOut, .cannotFindHost].contains(error.code) {
            return .network("Couldn't reach \(preset.displayName) at \(place) — is it running?")
        }
        return .network("Couldn't reach \(preset.displayName) at \(place): \(error.localizedDescription)")
    }
}
