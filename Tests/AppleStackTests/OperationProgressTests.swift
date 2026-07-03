import Testing
@testable import AppleStack

struct OperationProgressTests {
    @Test func progressKeepsRecentLogAndMarksCompletion() {
        var progress = OperationProgress(title: "Pull ubuntu", detail: "Starting...")

        progress.append("line 1\n")
        progress.append("line 2\n", maxLogLength: 10)
        progress.finish("Done")

        #expect(progress.detail == "Done")
        #expect(progress.isRunning == false)
        #expect(progress.log.hasSuffix("line 2\n"))
        #expect(progress.log.count <= 10)
    }

    @Test func progressSummaryUsesLatestNonEmptyChunk() {
        var progress = OperationProgress(title: "Export", detail: "Preparing...")

        progress.append("\n")
        progress.append("writing layer\n")

        #expect(progress.detail == "writing layer")
        #expect(progress.isRunning)
    }
}
