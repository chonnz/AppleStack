import Foundation

/// CLI 后端实现，通过 container 命令与容器运行时交互
final class CLIBackend: ContainerServiceProtocol, @unchecked Sendable {
    private let executor = CommandExecutor()
    private let containerPath: String

    init() {
        self.containerPath = Self.findContainerPath() ?? "/usr/local/bin/container"
    }

    /// 查找 container 命令路径
    private static func findContainerPath() -> String? {
        let paths = [
            "/usr/local/bin/container",
            "/opt/homebrew/bin/container",
            "/usr/bin/container",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/container").path,
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 尝试 which 命令
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["container"]
        process.standardOutput = pipe
        process.standardError = pipe

        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = path, !path.isEmpty {
                return path
            }
        }

        return nil
    }

    /// 获取系统信息
    func getSystemInfo() async throws -> SystemInfo {
        let output = try await executor.execute(
            containerPath,
            arguments: ["system", "info", "--format", "json"]
        )

        guard let data = output.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        // 尝试解析为字典格式
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return SystemInfo(
                version: json["version"] as? String ?? "unknown",
                os: json["os"] as? String ?? "unknown",
                kernel: json["kernel"] as? String ?? "unknown",
                arch: json["arch"] as? String ?? "unknown",
                containersRunning: json["containersRunning"] as? Int ?? 0,
                containersStopped: json["containersStopped"] as? Int ?? 0,
                images: json["images"] as? Int ?? 0
            )
        }

        throw CommandError.invalidOutput
    }

    /// 获取容器列表
    func listContainers(all: Bool = true) async throws -> [Container] {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.listContainersArguments(all: all)
        )

        return try parseContainerList(from: output)
    }

    static func listContainersArguments(all: Bool) -> [String] {
        var arguments = ["list", "--format", "json"]
        if all {
            arguments.append("--all")
        }
        return arguments
    }

    /// 解析容器列表 JSON（支持数组和多行 JSON 格式）
    private func parseContainerList(from output: String) throws -> [Container] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        // 尝试解析为 JSON 数组
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { parseContainer(from: $0) }
        }

        // 尝试解析多行 JSON（每行一个 JSON 对象）
        var containers: [Container] = []
        let lines = trimmed.components(separatedBy: .newlines)
        for line in lines {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else {
                continue
            }
            if let container = parseContainer(from: json) {
                containers.append(container)
            }
        }

        return containers
    }

    /// 从 JSON 字典解析容器对象
    private func parseContainer(from json: [String: Any]) -> Container? {
        guard let id = json["id"] as? String ?? json["ID"] as? String,
              let name = json["name"] as? String ?? json["Name"] as? String
        else {
            return nil
        }

        let image = json["image"] as? String ?? json["Image"] as? String ?? ""
        let statusStr = json["status"] as? String ?? json["Status"] as? String ?? ""
        let stateStr = json["state"] as? String ?? json["State"] as? String ?? ""
        let created = json["created"] as? String ?? json["CreatedAt"] as? String ?? ""
        let ports = json["ports"] as? String ?? json["Ports"] as? String ?? ""
        let cpus = json["cpus"] as? Int ?? json["CPUs"] as? Int ?? 1
        let memory = json["memory"] as? String ?? json["Memory"] as? String ?? "512m"

        let status = ContainerStatus(rawValue: statusStr.lowercased()) ?? .created
        let state = ContainerState(rawValue: stateStr.lowercased()) ?? .created

        return Container(
            id: id,
            name: name,
            image: image,
            status: status,
            state: state,
            created: created,
            ports: ports,
            cpus: cpus,
            memory: memory
        )
    }

    /// 获取镜像列表
    func listImages() async throws -> [Image] {
        let output = try await executor.execute(
            containerPath,
            arguments: ["image", "list", "--format", "json"]
        )

        return try parseImageList(from: output)
    }

    /// 解析镜像列表 JSON
    private func parseImageList(from output: String) throws -> [Image] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        // 尝试解析为 JSON 数组
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { parseImage(from: $0) }
        }

        // 尝试解析多行 JSON
        var images: [Image] = []
        let lines = trimmed.components(separatedBy: .newlines)
        for line in lines {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else {
                continue
            }
            if let image = parseImage(from: json) {
                images.append(image)
            }
        }

        return images
    }

    /// 从 JSON 字典解析镜像对象
    private func parseImage(from json: [String: Any]) -> Image? {
        guard let id = json["id"] as? String ?? json["ID"] as? String else {
            return nil
        }

        let repository = json["repository"] as? String ?? json["Repository"] as? String ?? ""
        let tag = json["tag"] as? String ?? json["Tag"] as? String ?? ""
        let size = json["size"] as? Int64 ?? json["Size"] as? Int64 ?? 0
        let created = json["created"] as? String ?? json["CreatedAt"] as? String ?? ""

        return Image(
            id: id,
            repository: repository,
            tag: tag,
            size: size,
            created: created
        )
    }

    /// 创建并启动容器
    func createContainer(config: ContainerConfig) async throws -> String {
        var arguments = ["create"]

        if !config.name.isEmpty {
            arguments.append(contentsOf: ["--name", config.name])
        }

        arguments.append(contentsOf: ["--cpus", "\(config.cpus)"])
        arguments.append(contentsOf: ["--memory", config.memory])

        if !config.ports.isEmpty {
            arguments.append(contentsOf: ["--publish", config.ports])
        }

        for (key, value) in config.env {
            arguments.append(contentsOf: ["-e", "\(key)=\(value)"])
        }

        for volume in config.volumes {
            arguments.append(contentsOf: ["-v", volume])
        }

        if config.detach {
            arguments.append("--detach")
        }

        arguments.append(config.image)

        let output = try await executor.execute(
            containerPath,
            arguments: arguments
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 停止容器
    func stopContainer(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.stopContainerArguments(id: id)
        )
    }

    static func stopContainerArguments(id: String) -> [String] {
        ["stop", id]
    }

    /// 启动容器
    func startContainer(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.startContainerArguments(id: id)
        )
    }

    static func startContainerArguments(id: String) -> [String] {
        ["start", id]
    }

    /// 删除容器
    func removeContainer(id: String, force: Bool = false) async throws {
        let arguments = Self.removeContainerArguments(id: id, force: force)

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    static func removeContainerArguments(id: String, force: Bool) -> [String] {
        var arguments = ["rm"]
        if force {
            arguments.append("--force")
        }
        arguments.append(id)
        return arguments
    }

    /// 拉取镜像
    func pullImage(name: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["image", "pull", name]
        )
    }

    /// 删除镜像
    func removeImage(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["image", "delete", id]
        )
    }

    /// 执行容器命令
    func execCommand(containerId: String, command: [String]) async throws -> String {
        var arguments = ["exec", containerId]
        arguments.append(contentsOf: command)

        return try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    /// 获取容器日志（支持流式输出）
    func logs(containerId: String, follow: Bool = false, tail: Int? = nil) async throws -> String {
        var arguments = ["logs"]

        if follow {
            arguments.append("--follow")
        }

        if let tail = tail {
            arguments.append(contentsOf: ["--tail", "\(tail)"])
        }

        arguments.append(containerId)

        return try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    /// 获取容器资源使用情况
    func stats(containerId: String) async throws -> ContainerStats {
        let output = try await executor.execute(
            containerPath,
            arguments: ["stats", containerId, "--format", "json", "--no-stream"]
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return ContainerStats(
                cpuPercent: json["cpu_percent"] as? Double ?? 0,
                memoryUsage: json["memory_usage"] as? String ?? "0B",
                memoryLimit: json["memory_limit"] as? String ?? "0B",
                memoryPercent: json["memory_percent"] as? Double ?? 0,
                networkIO: json["network_io"] as? String ?? "0B / 0B",
                blockIO: json["block_io"] as? String ?? "0B / 0B",
                pids: json["pids"] as? Int ?? 0
            )
        }

        throw CommandError.invalidOutput
    }

    /// 启动系统
    func systemStart() async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["system", "start"]
        )
    }

    /// 停止系统
    func systemStop() async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["system", "stop"]
        )
    }

    // MARK: - Volume Operations

    /// 获取卷列表
    func listVolumes() async throws -> [String] {
        let output = try await executor.execute(
            containerPath,
            arguments: ["volume", "list", "--format", "json"]
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        // 尝试解析为 JSON 数组
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { $0["name"] as? String }
        }

        // 尝试按行解析
        return trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 创建卷
    func createVolume(name: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["volume", "create", name]
        )
    }

    /// 删除卷
    func removeVolume(name: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["volume", "rm", name]
        )
    }

    // MARK: - Network Operations

    /// 获取网络列表
    func listNetworks() async throws -> [Network] {
        let output = try await executor.execute(
            containerPath,
            arguments: ["network", "list", "--format", "json"]
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { parseNetwork(from: $0) }
        }

        return []
    }

    /// 从 JSON 解析网络对象
    private func parseNetwork(from json: [String: Any]) -> Network? {
        guard let id = json["id"] as? String ?? json["ID"] as? String,
              let name = json["name"] as? String ?? json["Name"] as? String
        else {
            return nil
        }

        let driver = json["driver"] as? String ?? json["Driver"] as? String ?? "bridge"
        let scope = json["scope"] as? String ?? json["Scope"] as? String ?? "local"
        let ipamDriver = json["ipam_driver"] as? String ?? json["IPAMDriver"] as? String ?? "default"
        let subnet = json["subnet"] as? String ?? json["Subnet"] as? String ?? ""
        let gateway = json["gateway"] as? String ?? json["Gateway"] as? String ?? ""
        let containers = json["containers"] as? Int ?? json["Containers"] as? Int ?? 0

        return Network(
            id: id,
            name: name,
            driver: driver,
            scope: scope,
            ipamDriver: ipamDriver,
            subnet: subnet,
            gateway: gateway,
            containers: containers
        )
    }

    /// 创建网络
    func createNetwork(config: NetworkConfig) async throws {
        var arguments = ["network", "create"]

        if !config.name.isEmpty {
            arguments += ["--name", config.name]
        }

        if !config.driver.isEmpty {
            arguments += ["--driver", config.driver]
        }

        if !config.subnet.isEmpty {
            arguments += ["--subnet", config.subnet]
        }

        if !config.gateway.isEmpty {
            arguments += ["--gateway", config.gateway]
        }

        if config.isInternal {
            arguments.append("--internal")
        }

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    /// 删除网络
    func removeNetwork(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["network", "rm", id]
        )
    }

    /// 连接容器到网络
    func connectNetwork(networkId: String, containerId: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["network", "connect", networkId, containerId]
        )
    }

    /// 断开容器与网络的连接
    func disconnectNetwork(networkId: String, containerId: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["network", "disconnect", networkId, containerId]
        )
    }

    // MARK: - Machine Operations

    /// 获取机器列表
    func listMachines() async throws -> [Machine] {
        let output = try await executor.execute(
            containerPath,
            arguments: ["machine", "list", "--format", "json"]
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { parseMachine(from: $0) }
        }

        return []
    }

    /// 从 JSON 解析机器对象
    private func parseMachine(from json: [String: Any]) -> Machine? {
        guard let id = json["id"] as? String ?? json["ID"] as? String,
              let name = json["name"] as? String ?? json["Name"] as? String
        else {
            return nil
        }

        let statusStr = json["status"] as? String ?? json["Status"] as? String ?? "stopped"
        let image = json["image"] as? String ?? json["Image"] as? String ?? ""
        let cpus = json["cpus"] as? Int ?? json["CPUs"] as? Int ?? 2
        let memory = json["memory"] as? String ?? json["Memory"] as? String ?? "2g"
        let disk = json["disk"] as? String ?? json["Disk"] as? String ?? "20g"
        let ip = json["ip"] as? String ?? json["IP"] as? String ?? ""
        let created = json["created"] as? String ?? json["CreatedAt"] as? String ?? ""

        let status = MachineStatus(rawValue: statusStr) ?? .stopped

        return Machine(
            id: id,
            name: name,
            status: status,
            image: image,
            cpus: cpus,
            memory: memory,
            disk: disk,
            ip: ip,
            created: created
        )
    }

    /// 创建机器
    func createMachine(config: MachineConfig) async throws {
        var arguments = ["machine", "create"]

        if !config.name.isEmpty {
            arguments += ["--name", config.name]
        }

        if !config.image.isEmpty {
            arguments += ["--image", config.image]
        }

        arguments += ["--cpus", "\(config.cpus)"]
        arguments += ["--memory", config.memory]
        arguments += ["--disk", config.disk]

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    /// 启动机器
    func startMachine(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["machine", "start", id]
        )
    }

    /// 停止机器
    func stopMachine(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["machine", "stop", id]
        )
    }

    /// 删除机器
    func removeMachine(id: String, force: Bool = false) async throws {
        var arguments = ["machine", "rm"]
        if force {
            arguments.append("--force")
        }
        arguments.append(id)

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    /// 重启机器
    func restartMachine(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["machine", "restart", id]
        )
    }
}
