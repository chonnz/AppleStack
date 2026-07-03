import Foundation
import Testing

struct ReleasePackagingTests {
    @Test func buildScriptPackagesReleaseDMGWithFirstOpenInstructions() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        let releaseNotes = try String(contentsOf: root.appendingPathComponent("RELEASE_NOTES.md"), encoding: .utf8)

        #expect(script.contains("Resources/AppIcon.icns"))
        #expect(script.contains("ln -s /Applications"))
        #expect(script.contains("First Open.txt"))
        #expect(releaseNotes.contains("First Open.txt"))
    }
}
