#if !APPSTORE
import Foundation

/// Locates and runs an AI CLI (`claude`, `codex`). Direct-distribution build only — a sandboxed
/// app can't run these tools or read their logins.
public enum CLITool: Sendable {
    case claude, codex

    var executableName: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        }
    }

    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }

    /// Where installers put these tools. GUI apps get a minimal PATH, so we look ourselves.
    public static func searchDirectories(home: String = NSHomeDirectory()) -> [String] {
        ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "\(home)/.npm-global/bin",
         "\(home)/.bun/bin", "\(home)/.volta/bin", "/usr/bin"]
    }

    /// The override path if it's executable, otherwise the first match in `directories`.
    public func locate(override: String, directories: [String] = CLITool.searchDirectories()) -> URL? {
        let fm = FileManager.default
        let trimmed = (override as NSString).expandingTildeInPath.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return fm.isExecutableFile(atPath: trimmed) ? URL(fileURLWithPath: trimmed) : nil
        }
        for directory in directories {
            let path = "\(directory)/\(executableName)"
            if fm.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }
}

struct CLIInvocation: Sendable {
    var executable: URL
    var arguments: [String]
    var stdin: String
    var extraEnvironment: [String: String] = [:]
    var toolName: String
}

/// Runs a process and streams its stdout line by line. Cancelling the stream terminates the
/// process. A non-zero exit surfaces the last stderr line.
enum CLIRunner {
    static func lines(_ invocation: CLIInvocation) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let job = CLIJob(invocation: invocation, continuation: continuation)
            continuation.onTermination = { _ in job.cancel() }
            job.start()
        }
    }

    /// PATH for the child: our search directories first (CLIs are often Node scripts that need
    /// `node` from the same place), then whatever we inherited.
    static func environment(extra: [String: String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inherited = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (CLITool.searchDirectories() + [inherited]).joined(separator: ":")
        environment.merge(extra) { _, new in new }
        return environment
    }
}

/// Owns one child process. Reading happens on a dedicated thread (blocking reads don't belong
/// on Swift's cooperative pool).
private final class CLIJob: @unchecked Sendable {
    private let invocation: CLIInvocation
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lock = NSLock()
    private var cancelled = false
    private var stderrData = Data()
    private let stderrDone = DispatchSemaphore(value: 0)

    init(invocation: CLIInvocation, continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.invocation = invocation
        self.continuation = continuation
    }

    func start() {
        process.executableURL = invocation.executable
        process.arguments = invocation.arguments
        process.environment = CLIRunner.environment(extra: invocation.extraEnvironment)
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            continuation.finish(throwing: ProviderError.process("Couldn't start \(invocation.toolName): \(error.localizedDescription)"))
            return
        }

        let input = Data(invocation.stdin.utf8)
        let stdinHandle = stdinPipe.fileHandleForWriting
        Thread.detachNewThread {
            try? stdinHandle.write(contentsOf: input)
            try? stdinHandle.close()
        }
        let stderrHandle = stderrPipe.fileHandleForReading
        Thread.detachNewThread { [self] in
            let data = stderrHandle.readDataToEndOfFile()
            lock.withLock { stderrData = data }
            stderrDone.signal()
        }
        Thread.detachNewThread { [self] in readStdout() }
    }

    func cancel() {
        lock.withLock { cancelled = true }
        if process.isRunning { process.terminate() }
    }

    private func readStdout() {
        let handle = stdoutPipe.fileHandleForReading
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
                buffer.removeSubrange(buffer.startIndex...newline)
                if !line.isEmpty { continuation.yield(line) }
            }
        }
        if !buffer.isEmpty { continuation.yield(String(decoding: buffer, as: UTF8.self)) }

        process.waitUntilExit()
        stderrDone.wait()
        let (wasCancelled, stderr) = lock.withLock { (cancelled, stderrData) }
        if wasCancelled {
            continuation.finish()
            return
        }
        let status = process.terminationStatus
        guard status == 0 else {
            let lastLine = String(decoding: stderr, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .last.map(String.init)?
                .trimmingCharacters(in: .whitespaces)
            let message = lastLine.flatMap { $0.isEmpty ? nil : "\(invocation.toolName): \($0)" }
                ?? "\(invocation.toolName) stopped unexpectedly (exit status \(status))."
            continuation.finish(throwing: ProviderError.process(message))
            return
        }
        continuation.finish()
    }
}
#endif
