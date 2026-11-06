#if !APPSTORE
import Foundation
import Testing
@testable import PreviewAICore

@Suite struct CLIProviderTests {
    let request = SummaryRequest(system: "SYSTEM PROMPT", user: "USER DOCUMENT", maxOutputTokens: 1_200)
    let fakeBin = TestSupport.fixture("bin").path

    func log() throws -> String {
        try TestSupport.scratch().appendingPathComponent("cli").path
    }

    func claude(mode: String, model: String = "", log: String) -> ClaudeCodeProvider {
        var config = CLIConfig()
        config.model = model
        var provider = ClaudeCodeProvider(config: config, directories: [fakeBin])
        provider.extraEnvironment = ["FAKE_MODE": mode, "FAKE_LOG": log]
        return provider
    }

    func codex(mode: String, model: String = "", log: String) -> CodexProvider {
        var config = CLIConfig()
        config.model = model
        var provider = CodexProvider(config: config, directories: [fakeBin])
        provider.extraEnvironment = ["FAKE_MODE": mode, "FAKE_LOG": log]
        return provider
    }

    func lines(_ path: String) throws -> [String] {
        let parts: [String] = try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: "\n")
        return Array(parts.dropLast())  // trailing newline
    }

    // MARK: Claude Code

    @Test func claudeGetsExactFlagsAndDocumentOnStdin() async throws {
        let log = try log()
        let result = await collect(claude(mode: "deltas", model: "sonnet", log: log).stream(request))
        #expect(result.error == nil)
        let args = try lines(log + ".args")
        #expect(args == [
            "-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
            "--tools", "", "--no-session-persistence", "--disable-slash-commands", "--strict-mcp-config",
            "--setting-sources", "project", "--effort", "low",
            "--system-prompt", "SYSTEM PROMPT", "--model", "sonnet",
        ])
        #expect(!args.contains("--bare"))
        #expect(try String(contentsOfFile: log + ".stdin", encoding: .utf8) == "USER DOCUMENT")
    }

    @Test func claudeOmitsModelWhenEmpty() async throws {
        let log = try log()
        _ = await collect(claude(mode: "deltas", log: log).stream(request))
        #expect(!(try lines(log + ".args")).contains("--model"))
    }

    @Test func claudeStreamsTextDeltasOnly() async throws {
        let result = await collect(claude(mode: "deltas", log: try log()).stream(request))
        #expect(result.text == "**TL;DR** From Claude.")
    }

    @Test func claudeFallsBackToResultWithoutDeltas() async throws {
        let result = await collect(claude(mode: "result-only", log: try log()).stream(request))
        #expect(result.error == nil)
        #expect(result.text == "Only the result.")
    }

    @Test func claudeErrorResultThrows() async throws {
        let result = await collect(claude(mode: "error", log: try log()).stream(request))
        guard case .process(let message)? = result.error as? ProviderError else { Issue.record("\(String(describing: result.error))"); return }
        #expect(message.contains("Please run /login"))
        #expect(message.contains("run `claude` in Terminal"))
    }

    @Test func nonZeroExitSurfacesLastStderrLine() async throws {
        let result = await collect(claude(mode: "exit", log: try log()).stream(request))
        #expect(result.error as? ProviderError == .process("Claude Code: fatal: something broke"))
    }

    @Test func cancellingTerminatesTheProcess() async throws {
        let log = try log()
        let provider = claude(mode: "slow", log: log)
        let started = ContinuousClock.now
        let task = Task {
            for try await _ in provider.stream(request) { break }  // first chunk, then stop
        }
        _ = await task.result
        let pidText = try String(contentsOfFile: log + ".pid", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = try #require(pid_t(pidText))
        let deadline = ContinuousClock.now + .seconds(3)
        while kill(pid, 0) == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(kill(pid, 0) != 0, "fake claude (pid \(pid)) still running after cancel")
        #expect(ContinuousClock.now - started < .seconds(10))
    }

    // MARK: Codex

    @Test func codexGetsExactFlagsAndPromptOnStdin() async throws {
        let log = try log()
        let result = await collect(codex(mode: "ok", model: "gpt-x", log: log).stream(request))
        #expect(result.error == nil)
        #expect(try lines(log + ".args") == [
            "exec", "--json", "--skip-git-repo-check", "--sandbox", "read-only", "--ephemeral",
            "-C", "/", "-c", "model_reasoning_effort=\"low\"", "-m", "gpt-x", "-",
        ])
        let stdin = try String(contentsOfFile: log + ".stdin", encoding: .utf8)
        #expect(stdin.hasPrefix("SYSTEM PROMPT"))
        #expect(stdin.contains("Do not run commands"))
        #expect(stdin.hasSuffix("USER DOCUMENT"))
    }

    @Test func codexYieldsAgentMessage() async throws {
        let result = await collect(codex(mode: "ok", log: try log()).stream(request))
        #expect(result.text == "**TL;DR** From Codex.")
    }

    @Test func codexTurnFailureThrows() async throws {
        let result = await collect(codex(mode: "failed", log: try log()).stream(request))
        #expect(result.error as? ProviderError == .process("Codex: You have hit your usage limit."))
    }

    // MARK: Discovery

    @Test func discoveryPrefersOverrideThenSearchDirectories() throws {
        let dir = try TestSupport.scratch()
        let custom = dir.appendingPathComponent("my-claude")
        try "#!/bin/sh\n".write(to: custom, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: custom.path)

        #expect(CLITool.claude.locate(override: custom.path, directories: [fakeBin]) == custom)
        #expect(CLITool.claude.locate(override: "", directories: [dir.path, fakeBin])?.path == fakeBin + "/claude")
        #expect(CLITool.claude.locate(override: "", directories: [dir.path]) == nil)
        // A bad override doesn't silently fall back to some other binary.
        #expect(CLITool.claude.locate(override: dir.appendingPathComponent("nope").path, directories: [fakeBin]) == nil)
        #expect(CLITool.searchDirectories(home: "/Users/x").contains("/Users/x/.local/bin"))
        #expect(CLITool.searchDirectories().contains("/opt/homebrew/bin"))
    }

    @Test func missingCLIIsUnavailable() async throws {
        let empty = try TestSupport.scratch().path
        guard case .unavailable(let reason) = await ClaudeCodeProvider(config: CLIConfig(), directories: [empty]).availability() else {
            Issue.record("should be unavailable"); return
        }
        #expect(reason.contains("isn't installed"))
        guard case .unavailable = await CodexProvider(config: CLIConfig(), directories: [empty]).availability() else {
            Issue.record("should be unavailable"); return
        }
        #expect(await ClaudeCodeProvider(config: CLIConfig(), directories: [fakeBin]).availability() == .ready)
    }

    @Test func parsersIgnoreNoise() {
        #expect(ClaudeCodeProvider.parse("not json") == nil)
        #expect(ClaudeCodeProvider.parse(#"{"type":"assistant"}"#) == nil)
        #expect(CodexProvider.parse(#"{"type":"item.completed","item":{"type":"reasoning","text":"x"}}"#) == nil)
    }
}
#endif
