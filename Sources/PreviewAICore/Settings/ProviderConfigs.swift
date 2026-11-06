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
    /// Empty means the preset's default.
    public var baseURL: String = ""
    public var model: String = ""
    public init() {}

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
