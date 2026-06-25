import Foundation

/// 新手创建虚拟机时展示的系统模板；底层镜像准备由工具自动完成。
struct MachineSystemTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let badge: String?
    let summary: String
    let baseImage: String
    let defaultMachineName: String
    let internalImageTag: String

    static let recommended = MachineSystemTemplate(
        id: "ubuntu-24-04",
        title: "Ubuntu 24.04 LTS",
        badge: "Recommended",
        summary: "Best choice for daily development",
        baseImage: "ubuntu:24.04",
        defaultMachineName: "ubuntu-dev",
        internalImageTag: "local/machine-ubuntu:24.04"
    )

    static let all: [MachineSystemTemplate] = [
        .recommended,
        .init(
            id: "ubuntu-22-04",
            title: "Ubuntu 22.04 LTS",
            badge: nil,
            summary: "Use this when older packages are required",
            baseImage: "ubuntu:22.04",
            defaultMachineName: "ubuntu-22-dev",
            internalImageTag: "local/machine-ubuntu:22.04"
        ),
        .init(
            id: "debian-12",
            title: "Debian 12",
            badge: nil,
            summary: "Stable and lightweight Linux environment",
            baseImage: "debian:12",
            defaultMachineName: "debian-dev",
            internalImageTag: "local/machine-debian:12"
        ),
    ]

    var containerfile: String {
        let startupProgramPath = ["/sbin", "init"].joined(separator: "/")
        return """
        FROM \(baseImage)

        ENV container docker

        RUN apt-get update && \
            apt-get install -y systemd systemd-sysv dbus sudo iproute2 iputils-ping curl vim && \
            apt-get clean && \
            rm -rf /var/lib/apt/lists/* && \
            : > /etc/machine-id && \
            : > /var/lib/dbus/machine-id && \
            systemctl mask systemd-firstboot.service systemd-resolved.service \
                dev-hugepages.mount sys-fs-fuse-connections.mount \
                systemd-remount-fs.service getty.target console-getty.service systemd-logind.service && \
            systemctl set-default multi-user.target

        VOLUME ["/sys/fs/cgroup"]

        STOPSIGNAL SIGRTMIN+3

        CMD ["\(startupProgramPath)"]
        """
    }

    func buildOptions(in templateDirectory: URL) -> ImageBuildOptions {
        let containerfileURL = templateDirectory.appendingPathComponent("Containerfile")
        return ImageBuildOptions(
            contextDirectory: templateDirectory.path,
            dockerfilePath: containerfileURL.path,
            tags: [internalImageTag],
            platform: "linux/arm64",
            dns: "8.8.8.8",
            buildArgs: [:],
            noCache: false,
            pull: false
        )
    }
}

struct MachineResourcePreset: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let cpus: Int
    let memory: String

    static let light = MachineResourcePreset(
        id: "light",
        title: "Light",
        summary: "2 cores / 2 GB",
        cpus: 2,
        memory: "2G"
    )

    static let standard = MachineResourcePreset(
        id: "standard",
        title: "Standard",
        summary: "4 cores / 4 GB",
        cpus: 4,
        memory: "4G"
    )

    static let performance = MachineResourcePreset(
        id: "performance",
        title: "Performance",
        summary: "8 cores / 8 GB",
        cpus: 8,
        memory: "8G"
    )

    static let all: [MachineResourcePreset] = [.light, .standard, .performance]
}

extension MachineConfig {
    static func quickCreate(
        name: String,
        template: MachineSystemTemplate,
        resources: MachineResourcePreset,
        homeMount: String,
        setDefault: Bool,
        startAfterCreate: Bool
    ) -> MachineConfig {
        MachineConfig(
            name: name,
            image: template.internalImageTag,
            cpus: resources.cpus,
            memory: resources.memory,
            homeMount: homeMount,
            setDefault: setDefault,
            noBoot: !startAfterCreate
        )
    }
}
