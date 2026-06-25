import Testing
@testable import AppleStack

struct ContainerServiceErrorTests {
    @Test func detectsServiceNotRunningFromXPCError() {
        let error = CommandError.commandFailed(
            1,
            """
            Error: interrupted: "XPC connection error: Connection invalid"
            Ensure container system service has been started with `container system start`.
            """
        )

        #expect(ContainerServiceErrorPresenter.isServiceNotRunning(error))
        #expect(ContainerServiceErrorPresenter.message(for: error) == "Container system service is not running. Click Start System or run `container system start`.")
    }

    @Test func missingCLIMessageGivesInstallAndSettingsNextStep() {
        let error = CommandError.executionFailed("The file “container” couldn’t be opened because there is no such file.")

        let message = ContainerServiceErrorPresenter.message(for: error)

        #expect(message.contains("Apple container CLI"))
        #expect(message.contains("Settings > CLI"))
    }

    @Test func machineImageBuildMessageExplainsDNSFailures() {
        let error = CommandError.commandFailed(
            1,
            "E: Temporary failure resolving 'archive.ubuntu.com'"
        )

        let message = ContainerServiceErrorPresenter.machineImageBuildMessage(
            for: error,
            buildLog: "apt-get update\nTemporary failure resolving 'archive.ubuntu.com'",
            dockerfilePath: "Containerfile",
            contextDirectory: "/tmp/machine"
        )

        #expect(message.contains("DNS"))
        #expect(message.contains("8.8.8.8"))
        #expect(message.contains("/tmp/machine"))
    }

    @Test func machineImageBuildMessageExplainsMissingBuildFile() {
        let error = CommandError.commandFailed(
            1,
            "failed to read dockerfile: open /tmp/machine/Containerfile: no such file or directory"
        )

        let message = ContainerServiceErrorPresenter.machineImageBuildMessage(
            for: error,
            buildLog: "",
            dockerfilePath: "Containerfile",
            contextDirectory: "/tmp/machine"
        )

        #expect(message.contains("未找到构建文件"))
        #expect(message.contains("Containerfile"))
        #expect(message.contains("/tmp/machine"))
    }
}
