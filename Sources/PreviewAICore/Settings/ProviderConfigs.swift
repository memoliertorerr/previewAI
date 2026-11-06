import Foundation

public struct AnthropicConfig: Codable, Equatable, Sendable {
    public static let models = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
    public var model: String = "claude-opus-5-5"
    public init() {}
}

/// OpenAI's API and anything that speaks its Chat Completions dialect.
public enum OpenAICompatiblePreset: String, Codable, CaseIterable, Sendable {
    case openAI, ollama, lmStudio, custom

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        case .custom: "Custom"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .ollama: "http://localhost:11434/v1"
        case .lmStudio: "http://localhost:1234/v1"
        case .custom: ""
        }
    }

    /// Local servers don't need a key.
    public var needsAPIKey: Bool { self == .openAI }
    public var isLocal: Bool { self == .ollama || self == .lmStudio }
}

public struct OpenAICompatibleConfig: Codable, Equatable, Sendable {
    public var preset: OpenAICompatiblePreset = .openAI
    /// Server URL overrides, kept per preset so a URL typed for one preset is never used with
    /// another preset's API key.
    public var baseURLs: [String: String] = [:]
    public var model: String = ""
    public init() {}

    /// The current preset's URL override (empty means the preset's default). OpenAI's URL
    /// can't be overridden — its key must only ever go to api.openai.com.
    public var baseURL: String {
        get { preset == .openAI ? "" : baseURLs[preset.rawValue] ?? "" }
        set {
            guard preset != .openAI else { return }
            baseURLs[preset.rawValue] = newValue
        }
    }

    public var effectiveBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? preset.defaultBaseURL : trimmed
    }
}

/// Claude Code / Codex CLIs.
public struct CLIConfig: Codable, Equatable, Sendable {
    /// Empty means auto-detect.
    public var binaryPath: String = ""
    /// Empty means the CLI's own default model.
    public var model: String = ""
    public init() {}
}
