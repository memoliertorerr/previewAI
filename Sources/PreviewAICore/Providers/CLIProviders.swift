#if !APPSTORE
import Foundation

/// Claude through the user's Claude subscription, via `claude -p` (Claude Code).
public struct ClaudeCodeProvider: SummaryProvider {
    public let id = ProviderID.claudeCode
    public let displayName = "Claude Code"
    public let modelName: String
    public let inputBudget = 400_000
    let executable: URL?
    var extraEnvironment: [String: String] = [:]

    public init(config: CLIConfig, directories: [String] = CLITool.searchDirectories()) {
        modelName = config.model.trimmingCharacters(in: .whitespaces)
        executable = CLITool.claude.locate(override: config.binaryPath, directories: directories)
    }

    public func availability() async -> ProviderAvailability {
        executable == nil
            ? .unavailable("Claude Code isn't installed (no `claude` found). Install it, or set its path in PreviewAI Settings.")
            : .ready
    }

    /// Never `--bare`: bare mode ignores the subscription login and only reads ANTHROPIC_API_KEY.
    /// Running in `/` with only project settings loads none of the user's hooks, plugins, or
    /// CLAUDE.md files; no tools, no MCP, no saved session.
    func arguments(for request: SummaryRequest) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--tools", "",
            "--no-session-persistence",
            "--disable-slash-commands",
            "--strict-mcp-config",
            "--setting-sources", "project",
            "--effort", "low",
            "--system-prompt", request.system,
        ]
        if !modelName.isEmpty { arguments += ["--model", modelName] }
        return arguments
    }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        guard let executable else {
            return AsyncThrowingStream { $0.finish(throwing: ProviderError.unavailable("Claude Code isn't installed.")) }
        }
        let invocation = CLIInvocation(executable: executable, arguments: arguments(for: request), stdin: request.user,
                                       extraEnvironment: extraEnvironment, toolName: "Claude Code")
        return AsyncThrowingStream { continuation in
            let task = Task {
                var sawDelta = false
                do {
                    for try await line in CLIRunner.lines(invocation) {
                        switch Self.parse(line) {
                        case .delta(let text):
                            sawDelta = true
                            continuation.yield(text)
                        case .result(let text):
                            if !sawDelta { continuation.yield(text) }
                        case .failure(let message):
                            throw ProviderError.process(message)
                        case nil:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    enum Line: Equatable {
        case delta(String), result(String), failure(String)
    }

    static func parse(_ line: String) -> Line? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return nil }
        switch json["type"] as? String {
        case "stream_event":
            guard let event = json["event"] as? [String: Any], event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String else { return nil }
            return .delta(text)
        case "result":
            let text = json["result"] as? String ?? ""
            if json["is_error"] as? Bool == true || (json["subtype"] as? String).map({ $0 != "success" }) == true {
                let detail = text.isEmpty ? "Claude Code reported an error." : text
                return .failure("Claude Code: \(detail) If you're not logged in, run `claude` in Terminal once.")
            }
            return .result(text)
        default:
            return nil
        }
    }
}

/// OpenAI models through the user's ChatGPT/Codex subscription, via `codex exec`.
public struct CodexProvider: SummaryProvider {
    public let id = ProviderID.codex
    public let displayName = "Codex"
    public let modelName: String
    public let inputBudget = 400_000
    let executable: URL?
    var extraEnvironment: [String: String] = [:]

    public init(config: CLIConfig, directories: [String] = CLITool.searchDirectories()) {
        modelName = config.model.trimmingCharacters(in: .whitespaces)
        executable = CLITool.codex.locate(override: config.binaryPath, directories: directories)
    }

    public func availability() async -> ProviderAvailability {
        executable == nil
            ? .unavailable("Codex isn't installed (no `codex` found). Install it, or set its path in PreviewAI Settings.")
            : .ready
    }

    /// Read-only sandbox, no session saved, run outside any repo; prompt comes on stdin (`-`).
    func arguments() -> [String] {
        var arguments = [
            "exec",
            "--json",
            "--skip-git-repo-check",
            "--sandbox", "read-only",
            "--ephemeral",
            "-C", "/",
            "-c", "model_reasoning_effort=\"low\"",
        ]
        if !modelName.isEmpty { arguments += ["-m", modelName] }
        arguments.append("-")
        return arguments
    }

    /// Codex has no system-prompt flag, so instructions lead the prompt.
    static func prompt(for request: SummaryRequest) -> String {
        """
        \(request.system)
        The complete document is included below. Do not run commands or read files — answer from the text only.

        \(request.user)
        """
    }

    public func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error> {
        guard let executable else {
            return AsyncThrowingStream { $0.finish(throwing: ProviderError.unavailable("Codex isn't installed.")) }
        }
        let invocation = CLIInvocation(executable: executable, arguments: arguments(), stdin: Self.prompt(for: request),
                                       extraEnvironment: extraEnvironment, toolName: "Codex")
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in CLIRunner.lines(invocation) {
                        switch Self.parse(line) {
                        case .message(let text): continuation.yield(text)
                        case .failure(let message): throw ProviderError.process(message)
                        case nil: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    enum Line: Equatable {
        case message(String), failure(String)
    }

    static func parse(_ line: String) -> Line? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return nil }
        switch json["type"] as? String {
        case "item.completed":
            guard let item = json["item"] as? [String: Any], item["type"] as? String == "agent_message",
                  let text = item["text"] as? String else { return nil }
            return .message(text)
        case "turn.failed":
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "the request failed."
            return .failure("Codex: \(message)")
        case "error":
            return .failure("Codex: \(json["message"] as? String ?? "an error occurred.")")
        default:
            return nil
        }
    }
}
#endif
