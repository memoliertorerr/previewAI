import Foundation

/// Test helpers. Tests never write outside the repo: scratch files live under
/// `.build/test-scratch/`, never `$TMPDIR`.
enum TestSupport {
    static let repoRoot: URL = {
        // .../Tests/PreviewAICoreTests/TestSupport.swift → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    /// A fresh, empty directory for one test.
    static func scratch() throws -> URL {
        let dir = repoRoot
            .appendingPathComponent(".build/test-scratch", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fixture(_ name: String) -> URL {
        repoRoot.appendingPathComponent("Tests/PreviewAICoreTests/Fixtures/\(name)")
    }
}
