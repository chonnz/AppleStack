import Foundation

/// CLI 后端实现，通过 container 命令与容器运行时交互
final class CLIBackend: ContainerServiceProtocol {
    private let executor = CommandExecutor()
    private let containerPath = "/usr/local/bin/container"

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
        var arguments = ["container", "list", "--format", "json"]
        if all {
            arguments.append("--all")
        }

        let output = try await executor.execute(
            containerPath,
            arguments: arguments
        )

        return try parseContainerList(from: output)
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
        var arguments = ["container", "create"]

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
            arguments: ["container", "stop", id]
        )
    }

    /// 启动容器
    func startContainer(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["container", "start", id]
        )
    }

    /// 删除容器
    func removeContainer(id: String, force: Bool = false) async throws {
        var arguments = ["container", "rm"]
        if force {
            arguments.append("--force")
        }
        arguments.append(id)

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
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
            arguments: ["image", "rm", id]
        )
    }

    /// 执行容器命令
    func execCommand(containerId: String, command: [String]) async throws -> String {
        var arguments = ["container", "exec", containerId]
        arguments.append(contentsOf: command)

        return try await executor.execute(
            containerPath,
            arguments: arguments
        )
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
}
