import Foundation
import Testing
@testable import AppleStack

struct ContainerServiceFactoryTests {
    @Test func frameworkBackendFallsBackToCLIUntilImplemented() {
        let service = ContainerServiceFactory.create(backend: .framework)

        #expect(service is CLIBackend)
    }

    @Test func cliBackendUsesConfiguredExecutablePathWhenRecreated() throws {
        let executableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("applestack-container-\(UUID().uuidString)")
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let backend = CLIBackend(configuredPath: executableURL.path)

        #expect(backend.executablePath == executableURL.path)
    }
}
