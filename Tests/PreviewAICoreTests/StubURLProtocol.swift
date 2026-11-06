import Foundation
@testable import PreviewAICore

/// Intercepts HTTP in tests. Each test registers a unique host, so parallel tests don't collide.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var status = 200
        var headers: [String: String] = ["content-type": "text/event-stream"]
        var chunks: [Data] = []
        var error: URLError?
    }

    struct Recorded: Sendable {
        var request: URLRequest
        var body: Data

        var json: [String: Any] { (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:] }
        func header(_ name: String) -> String? { request.value(forHTTPHeaderField: name) }
    }

    nonisolated(unsafe) private static var responses: [String: Response] = [:]
    nonisolated(unsafe) private static var recorded: [String: [Recorded]] = [:]
    private static let lock = NSLock()

    /// Registers a canned response for a fresh host and returns the base URL to use.
    static func register(_ response: Response) -> URL {
        let host = "stub-\(UUID().uuidString.lowercased()).test"
        lock.withLock { responses[host] = response }
        return URL(string: "https://\(host)")!
    }

    static func requests(for baseURL: URL) -> [Recorded] {
        lock.withLock { recorded[baseURL.host ?? ""] ?? [] }
    }

    static func client() -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return HTTPClient(configuration: configuration)
    }

    static func sse(_ events: [(String, String)]) -> [Data] {
        events.map { Data("event: \($0.0)\ndata: \($0.1)\n\n".utf8) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let body = Self.readBody(request)
        let response = Self.lock.withLock { () -> Response? in
            Self.recorded[host, default: []].append(Recorded(request: request, body: body))
            return Self.responses[host]
        }
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        for chunk in response.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Collects a provider stream into text, or the thrown error.
func collect(_ stream: AsyncThrowingStream<String, Error>) async -> (text: String, error: Error?) {
    var text = ""
    do {
        for try await chunk in stream { text += chunk }
        return (text, nil)
    } catch {
        return (text, error)
    }
}
