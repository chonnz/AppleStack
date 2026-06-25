import Testing
@testable import AppleStack

struct ContainerServiceFactoryTests {
    @Test func frameworkBackendFallsBackToCLIUntilImplemented() {
        let service = ContainerServiceFactory.create(backend: .framework)

        #expect(service is CLIBackend)
    }
}
