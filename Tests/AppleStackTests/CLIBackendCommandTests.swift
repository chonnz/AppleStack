import Testing
@testable import AppleStack

struct CLIBackendCommandTests {
    @Test func listContainersArgumentsDoNotRepeatExecutableName() {
        #expect(CLIBackend.listContainersArguments(all: true) == ["list", "--format", "json", "--all"])
        #expect(CLIBackend.listContainersArguments(all: false) == ["list", "--format", "json"])
    }

    @Test func lifecycleArgumentsDoNotRepeatExecutableName() {
        #expect(CLIBackend.startContainerArguments(id: "web") == ["start", "web"])
        #expect(CLIBackend.stopContainerArguments(id: "web") == ["stop", "web"])
        #expect(CLIBackend.removeContainerArguments(id: "web", force: false) == ["rm", "web"])
        #expect(CLIBackend.removeContainerArguments(id: "web", force: true) == ["rm", "--force", "web"])
    }
}
