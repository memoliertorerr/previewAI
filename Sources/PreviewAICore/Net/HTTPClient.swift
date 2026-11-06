import Foundation

/// Thin URLSession wrapper shared by the HTTP providers. Ephemeral configuration: no cookies
/// or response cache are written to disk.
public struct HTTPClient: Sendable {
    public let session: URLSession

    public static let shared = HTTPClient()

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        // Upper bound; requests set their own (cloud 60 s, local servers longer).
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    /// Starts a request and returns the streaming body. Non-2xx responses are read fully and
    /// returned as `HTTPFailure` so providers can map them.
    public func stream(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count > 64_000 { break }
            }
            throw HTTPFailure(status: status, body: body)
        }
        return bytes
    }

    public func data(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw HTTPFailure(status: status, body: data) }
        return data
    }
}

public struct HTTPFailure: Error, Sendable {
    public let status: Int
    public let body: Data

    /// Best-effort error message from common JSON error shapes
    /// (`{"error":{"message":…}}`, `{"error":"…"}`, `{"message":…}`).
    public var message: String {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return String(decoding: body.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let error = json["error"] as? String { return error }
        if let message = json["message"] as? String { return message }
        return ""
    }

    public var errorType: String? {
        ((try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? [String: Any])?["type"] as? String
    }
}
