import Testing
@testable import PreviewAICore

@Test func versionIsSet() {
    #expect(PreviewAIInfo.version == "0.1.0")
    #expect(PreviewAIInfo.bundleIdentifier == "com.memoliertorerr.PreviewAI")
}

@Test func scratchStaysInsideRepo() throws {
    let dir = try TestSupport.scratch()
    #expect(dir.path.hasPrefix(TestSupport.repoRoot.path))
    #expect(dir.path.contains("/.build/test-scratch/"))
}
