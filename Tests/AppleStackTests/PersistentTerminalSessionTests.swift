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

    @Test func machineTargetUsesOneShotCommandsInNativeTerminal() {
        let target = PersistentTerminalSession.Target.machine(id: "dev")
        #expect(target.usesOneShotCommands)
        #expect(target.oneShotArguments(command: "pwd") == ["machine", "run", "--name", "dev", "--", "/bin/sh", "-lc", "pwd"])
    }

    @Test func containerTargetKeepsPersistentShell() {
        let target = PersistentTerminalSession.Target.container(id: "web")
        #expect(!target.usesOneShotCommands)
        #expect(target.oneShotArguments(command: "pwd") == ["exec", "web", "/bin/sh", "-lc", "pwd"])
    }

    @Test func machineExternalTerminalCommandEscapesArguments() {
        let target = PersistentTerminalSession.Target.machine(id: "dev box's")
        #expect(target.externalTerminalCommand(executableName: "container") == "container machine run --name 'dev box'\\''s' --interactive -- /bin/sh")
    }
}
