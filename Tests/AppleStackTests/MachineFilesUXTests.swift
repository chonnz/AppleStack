import Testing
@testable import AppleStack

struct MachineFilesUXTests {
    @Test func machineFileQuickLocationsStaySmallAndUseful() {
        #expect(MachineFileQuickLocation.defaults.map(\.path) == ["/", "/home", "/etc", "/var/log"])
        #expect(MachineFileQuickLocation.defaults.map(\.title) == ["Root", "Home", "Config", "Logs"])
    }

    @Test func machineFileBrowserErrorAddsPathContext() {
        let message = MachineFileBrowserErrorMessage.describe(
            CommandError.commandFailed(1, "ls: cannot access '/root': Permission denied"),
            path: "/root"
        )

        #expect(message.contains("/root"))
        #expect(message.localizedCaseInsensitiveContains("permission"))
    }
}
