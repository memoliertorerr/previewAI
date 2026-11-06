import Foundation

public enum ConnectionTestResult: Equatable, Sendable {
    case success(String)
    case failure(String)
}

/// "Test connection" in Settings: a tiny real request through the configured provider.
public enum ConnectionTester {
    static let request = SummaryRequest(
        system: "You are checking that a connection works. Answer in a few words.",
        user: "Reply with exactly: PreviewAI connection OK",
        maxOutputTokens: 50
    )

    public static func run(_ provider: any SummaryProvider) async -> ConnectionTestResult {
        if case .unavailable(let reason) = await provider.availability() {
            return .failure(reason)
        }
        var reply = ""
        do {
            for try await chunk in provider.stream(request) {
                reply += chunk
                if reply.count > 200 { break }
            }
        } catch {
            return .failure(error.localizedDescription)
        }
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(ProviderError.emptyResponse.localizedDescription) }
        let name = provider.modelName.isEmpty ? provider.displayName : "\(provider.displayName) · \(provider.modelName)"
        return .success("Connected to \(name) — it replied “\(trimmed.prefix(80))”.")
    }
}
