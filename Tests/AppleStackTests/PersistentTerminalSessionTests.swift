import Testing
@testable import AppleStack

struct PersistentTerminalSessionTests {
    @Test func containerTargetLaunchesContainerShell() {
        let target = PersistentTerminalSession.Target.container(id: "web")
        #expect(target.launchArguments == ["exec", "--interactive", "web", "/bin/sh"])
    }

    @Test func machineTargetLaunchesMachineShell() {
        let target = PersistentTerminalSession.Target.machine(id: "dev")
        #expect(target.launchArguments == ["machine", "run", "--name", "dev", "--interactive", "--", "/bin/sh"])
    }

    @Test func machineExternalTerminalCommandEscapesArguments() {
        let target = PersistentTerminalSession.Target.machine(id: "dev box's")
        #expect(target.externalTerminalCommand(executableName: "container") == "container machine run --name 'dev box'\\''s' --interactive -- /bin/sh")
    }
}
