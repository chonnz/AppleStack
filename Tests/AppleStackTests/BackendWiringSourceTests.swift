import Foundation
import Testing

struct BackendWiringSourceTests {
    @Test func userFacingDetailViewsDoNotConstructStaleCLIBackends() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let checkedFiles = [
            "Sources/AppleStack/ContentView.swift",
            "Sources/AppleStack/Views/Containers/Detail/ContainerDetailView.swift",
            "Sources/AppleStack/Views/Volumes/VolumeDetailView.swift",
            "Sources/AppleStack/Views/Networks/NetworkDetailView.swift",
            "Sources/AppleStack/Views/Volumes/VolumeListView.swift",
            "Sources/AppleStack/Views/Networks/NetworkListView.swift",
        ]

        for relativePath in checkedFiles {
            let source = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            #expect(!source.contains("CLIBackend()"), "\(relativePath) should use the current environment backend")
            #expect(!source.contains("ContainerServiceFactory.create()"), "\(relativePath) should not bypass ContainerServiceStore")
        }
    }
}
