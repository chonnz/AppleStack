import Foundation
import Testing
@testable import AppleStack

struct CLIBackendCommandTests {
    @Test func listContainersArgumentsDoNotRepeatExecutableName() {
        #expect(CLIBackend.listContainersArguments(all: true) == ["list", "--format", "json", "--all"])
        #expect(CLIBackend.listContainersArguments(all: false) == ["list", "--format", "json"])
        #expect(CLIBackend.listContainersArguments(all: true, quiet: true) == ["list", "--format", "json", "--all", "--quiet"])
    }

    @Test func lifecycleArgumentsDoNotRepeatExecutableName() {
        #expect(CLIBackend.startContainerArguments(id: "web") == ["start", "web"])
        #expect(CLIBackend.stopContainerArguments(id: "web") == ["stop", "web"])
        #expect(CLIBackend.removeContainerArguments(id: "web", force: false) == ["delete", "web"])
        #expect(CLIBackend.removeContainerArguments(id: "web", force: true) == ["delete", "--force", "web"])
        #expect(CLIBackend.removeContainerArguments(force: false, all: true) == ["delete", "--all"])
    }

    @Test func systemStatusArgumentsUseExistingSubcommand() {
        #expect(CLIBackend.systemStatusArguments() == ["system", "status"])
    }

    @Test func terminalExecArgumentsDoNotDuplicateExecPrefix() {
        #expect(CLIBackend.execContainerArguments(containerId: "web", command: ["sh", "-lc", "pwd"]) == ["exec", "web", "sh", "-lc", "pwd"])
        #expect(CLIBackend.listContainerDirectoryArguments(containerId: "web", path: "/app data") == ["exec", "web", "/bin/sh", "-lc", "LC_ALL=C ls -la '/app data'"])
    }

    @Test func machineArgumentsUseAvailableSubcommands() {
        #expect(CLIBackend.stopMachineArguments(id: "dev") == ["machine", "stop", "dev"])
        #expect(CLIBackend.removeMachineArguments(id: "dev", force: false) == ["machine", "rm", "dev"])
        #expect(CLIBackend.removeMachineArguments(id: "dev", force: true) == ["machine", "rm", "dev"])
        #expect(CLIBackend.bootMachineArguments(id: "dev") == ["machine", "run", "--name", "dev", "--detach", "/bin/sleep", "infinity"])
        #expect(CLIBackend.runMachineArguments(id: "dev", command: ["uname", "-a"]) == ["machine", "run", "--name", "dev", "--", "uname", "-a"])
    }

    @Test func unavailableNetworkAttachmentCommandsAreNotConstructed() {
        #expect(CLIBackend.networkConnectArguments(networkId: "net", containerId: "web") == nil)
        #expect(CLIBackend.networkDisconnectArguments(networkId: "net", containerId: "web") == nil)
    }

    @Test func containerManagementArgumentsMatchCLI() {
        #expect(CLIBackend.inspectContainerArguments(ids: ["web", "db"]) == ["inspect", "web", "db"])
        #expect(CLIBackend.killContainerArguments(ids: ["web"], signal: nil, all: false) == ["kill", "web"])
        #expect(CLIBackend.killContainerArguments(ids: [], signal: "TERM", all: true) == ["kill", "--all", "--signal", "TERM"])
        #expect(CLIBackend.pruneContainersArguments() == ["prune"])
        #expect(CLIBackend.exportContainerArguments(id: "web", outputPath: nil) == ["export", "web"])
        #expect(CLIBackend.exportContainerArguments(id: "web", outputPath: "/tmp/web.tar") == ["export", "--output", "/tmp/web.tar", "web"])
        #expect(CLIBackend.copyContainerArguments(source: "web:/app", destination: "/tmp/app") == ["copy", "web:/app", "/tmp/app"])
        #expect(CLIBackend.containerLogsArguments(containerId: "web", follow: true, tail: 50, boot: true) == ["logs", "--boot", "--follow", "-n", "50", "web"])
        #expect(CLIBackend.statsArguments(containerId: "web") == ["stats", "web", "--format", "json", "--no-stream"])
    }

    @Test func runContainerArgumentsUseRunSubcommand() {
        let config = ContainerConfig(
            name: "web",
            image: "nginx:latest",
            cpus: 2,
            memory: "512m",
            ports: "8080:80",
            env: ["ENV": "prod"],
            volumes: ["/host:/container"],
            detach: true,
            interactive: true,
            tty: true,
            autoRemove: true,
            dns: "1.1.1.1"
        )

        #expect(CLIBackend.runContainerArguments(config: config, command: ["nginx", "-g", "daemon off;"]) == [
            "run", "--name", "web", "--cpus", "2", "--memory", "512m", "--publish", "8080:80", "--dns", "1.1.1.1", "-e", "ENV=prod", "-v", "/host:/container", "--detach", "--interactive", "--tty", "--rm", "nginx:latest", "nginx", "-g", "daemon off;",
        ])
    }

    @Test func imageManagementArgumentsMatchCLI() {
        #expect(CLIBackend.inspectImageArguments(references: ["nginx:latest"]) == ["image", "inspect", "nginx:latest"])
        #expect(CLIBackend.loadImageArguments(inputPath: "/tmp/image.tar", force: false) == ["image", "load", "--input", "/tmp/image.tar"])
        #expect(CLIBackend.loadImageArguments(inputPath: nil, force: true) == ["image", "load", "--force"])
        #expect(CLIBackend.saveImageArguments(references: ["nginx:latest"], outputPath: "/tmp/nginx.tar", platform: "linux/arm64") == ["image", "save", "--output", "/tmp/nginx.tar", "--platform", "linux/arm64", "nginx:latest"])
        #expect(CLIBackend.tagImageArguments(source: "nginx:latest", target: "local/nginx:test") == ["image", "tag", "nginx:latest", "local/nginx:test"])
        #expect(CLIBackend.pruneImagesArguments(all: false) == ["image", "prune"])
        #expect(CLIBackend.pruneImagesArguments(all: true) == ["image", "prune", "--all"])
        #expect(CLIBackend.pushImageArguments(reference: "repo/app:latest", platform: "linux/arm64") == ["image", "push", "--platform", "linux/arm64", "repo/app:latest"])
    }

    @Test func imageDeleteTargetPrefersReferenceForTaggedImages() {
        let taggedImage = Image(
            id: "f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64",
            repository: "ubuntu",
            tag: "latest",
            size: 40735215,
            created: "2026-04-21T15:26:17Z"
        )
        let danglingImage = Image(
            id: "abc123",
            repository: "<none>",
            tag: "",
            size: 1024,
            created: "2026-04-21T15:26:17Z"
        )

        #expect(taggedImage.deleteTarget == "ubuntu:latest")
        #expect(danglingImage.deleteTarget == "abc123")
    }

    @Test func buildImageArgumentsMatchCLI() {
        let options = ImageBuildOptions(
            contextDirectory: "/tmp/app",
            dockerfilePath: "Containerfile",
            tags: ["repo/app:latest"],
            platform: "linux/arm64",
            dns: "8.8.8.8",
            buildArgs: ["ENV": "prod"],
            noCache: true,
            pull: true
        )

        #expect(CLIBackend.buildImageArguments(options: options) == [
            "build", "--file", "Containerfile", "--tag", "repo/app:latest", "--platform", "linux/arm64", "--dns", "8.8.8.8", "--build-arg", "ENV=prod", "--no-cache", "--pull", "/tmp/app",
        ])
    }

    @Test func registryBuilderAndSystemArgumentsMatchCLI() {
        #expect(CLIBackend.registryListArguments() == ["registry", "list"])
        #expect(CLIBackend.registryLoginArguments(server: "ghcr.io", username: "user", scheme: "https", passwordStdin: true) == ["registry", "login", "--scheme", "https", "--password-stdin", "--username", "user", "ghcr.io"])
        #expect(CLIBackend.registryLogoutArguments(server: "ghcr.io") == ["registry", "logout", "ghcr.io"])

        #expect(CLIBackend.builderStatusArguments(format: "json") == ["builder", "status", "--format", "json"])
        #expect(CLIBackend.builderStartArguments() == ["builder", "start"])
        #expect(CLIBackend.builderStopArguments() == ["builder", "stop"])
        #expect(CLIBackend.builderDeleteArguments() == ["builder", "rm"])

        #expect(CLIBackend.systemVersionArguments() == ["system", "version"])
        #expect(CLIBackend.systemDiskUsageArguments() == ["system", "df"])
        #expect(CLIBackend.systemLogsArguments(follow: true, last: "10m") == ["system", "logs", "--follow", "--last", "10m"])
        #expect(CLIBackend.systemPropertyListArguments() == ["system", "property", "list"])
        #expect(CLIBackend.systemDNSListArguments() == ["system", "dns", "list"])
        #expect(CLIBackend.systemDNSCreateArguments(domain: "test.container", localhost: "127.0.0.1") == ["system", "dns", "create", "--localhost", "127.0.0.1", "test.container"])
        #expect(CLIBackend.systemDNSDeleteArguments(domain: "test.container") == ["system", "dns", "delete", "test.container"])
        #expect(CLIBackend.systemKernelSetArguments(path: "/tmp/kernel") == ["system", "kernel", "set", "/tmp/kernel"])
    }

    @Test func networkVolumeAndMachineArgumentsMatchCLI() {
        #expect(CLIBackend.inspectNetworkArguments(ids: ["net1", "net2"]) == ["network", "inspect", "net1", "net2"])
        #expect(CLIBackend.pruneNetworksArguments() == ["network", "prune"])
        #expect(CLIBackend.inspectVolumeArguments(names: ["data"]) == ["volume", "inspect", "data"])
        #expect(CLIBackend.pruneVolumesArguments() == ["volume", "prune"])

        #expect(CLIBackend.inspectMachineArguments(id: nil) == ["machine", "inspect"])
        #expect(CLIBackend.inspectMachineArguments(id: "dev") == ["machine", "inspect", "dev"])
        #expect(CLIBackend.machineLogsArguments(id: "dev", follow: true, tail: 50, boot: true) == ["machine", "logs", "--boot", "--follow", "-n", "50", "dev"])
        #expect(CLIBackend.setMachineArguments(id: "dev", cpus: 4, memory: "8G", homeMount: "ro") == ["machine", "set", "--name", "dev", "cpus=4", "memory=8G", "home-mount=ro"])
        #expect(CLIBackend.setDefaultMachineArguments(id: "dev") == ["machine", "set-default", "dev"])

        let machineConfig = MachineConfig(
            name: "dev",
            image: "alpine:3.22",
            cpus: 4,
            memory: "8G",
            disk: "20g",
            homeMount: "ro",
            setDefault: true,
            noBoot: true
        )
        #expect(CLIBackend.createMachineArguments(config: machineConfig) == ["machine", "create", "--name", "dev", "--cpus", "4", "--memory", "8G", "--home-mount", "ro", "--set-default", "--no-boot", "alpine:3.22"])
    }

    @Test func parseAppleContainerStatsArrayOutput() throws {
        let output = #"""
        [{"blockReadBytes":21053440,"blockWriteBytes":8192,"cpuUsageUsec":51241,"id":"test-nginx","memoryLimitBytes":1073741824,"memoryUsageBytes":27508736,"networkRxBytes":1365316,"networkTxBytes":602,"numProcesses":7}]
        """#

        let stats = try CLIBackend.parseStatsOutput(output, containerId: "test-nginx")

        #expect(stats.cpuPercent == 0)
        #expect(stats.cpuUsageUsec == 51241)
        #expect(stats.memoryUsage == "26.2 MB")
        #expect(stats.memoryLimit == "1 GB")
        #expect(stats.memoryPercent > 2.5 && stats.memoryPercent < 2.6)
        #expect(stats.networkIO == "1.3 MB / 602 bytes")
        #expect(stats.networkRx == "1.3 MB")
        #expect(stats.networkTx == "602 bytes")
        #expect(stats.blockIO == "20.1 MB / 8 KB")
        #expect(stats.blockRead == "20.1 MB")
        #expect(stats.blockWrite == "8 KB")
        #expect(stats.pids == 7)
    }

    @Test func derivedCPUPercentUsesConsecutiveSamples() {
        let previousTimestamp = Date(timeIntervalSince1970: 10)
        let currentTimestamp = Date(timeIntervalSince1970: 12)
        let stats = ContainerStats(
            cpuPercent: 0,
            cpuUsageUsec: 1_000_000,
            memoryUsage: "0 B",
            memoryLimit: "0 B",
            memoryPercent: 0,
            networkIO: "0 B / 0 B",
            networkRx: "0 B",
            networkTx: "0 B",
            blockIO: "0 B / 0 B",
            blockRead: "0 B",
            blockWrite: "0 B",
            pids: 0
        )

        let cpuPercent = stats.resolvedCPUPercent(
            previousUsageUsec: 500_000,
            previousTimestamp: previousTimestamp,
            currentTimestamp: currentTimestamp
        )

        #expect(cpuPercent == 25)
    }

    @Test func parseContainerDirectoryOutputKeepsNamesWithSpaces() {
        let output = """
        total 8
        drwxr-xr-x  3 root root  96 Jun 24 12:00 .
        drwxr-xr-x 18 root root 576 Jun 24 11:59 ..
        drwxr-xr-x  2 root root  64 Jun 24 12:01 app data
        -rw-r--r--  1 root root 128 Jun 24 12:02 config.json
        """

        let entries = CLIBackend.parseContainerDirectoryOutput(output)

        #expect(entries.map(\.name) == ["app data", "config.json"])
        #expect(entries.first?.isDirectory == true)
        #expect(entries.last?.size == "128")
    }

    @Test func parsedContainerDirectoryEntriesExposeDisplayKind() {
        let output = """
        total 8
        drwxr-xr-x  3 root root  96 Jun 24 12:00 .
        drwxr-xr-x 18 root root 576 Jun 24 11:59 ..
        drwxr-xr-x  2 root root  64 Jun 24 12:01 app
        lrwxrwxrwx  1 root root   7 Jun 24 12:02 bin -> usr/bin
        -rw-r--r--  1 root root 128 Jun 24 12:03 config.json
        """

        let entries = CLIBackend.parseContainerDirectoryOutput(output)

        #expect(entries.map(\.kind) == ["Folder", "Symlink", "File"])
    }
}
