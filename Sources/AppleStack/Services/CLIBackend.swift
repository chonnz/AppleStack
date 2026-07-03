import Foundation

struct ContainerFileEntry: Identifiable, Equatable {
    let permissions: String
    let owner: String
    let group: String
    let size: String
    let modified: String
    let name: String
    let isDirectory: Bool

    var id: String { name }

    var kind: String {
        if isDirectory {
            return "Folder"
        }
        if permissions.hasPrefix("l") || name.contains(" -> ") {
            return "Symlink"
        }
        return "File"
    }
}

/// CLI 后端实现，通过 container 命令与容器运行时交互
final class CLIBackend: ContainerServiceProtocol, @unchecked Sendable {
    private let executor = CommandExecutor()
    private let containerPath: String

    var executablePath: String { containerPath }

    init(configuredPath: String? = UserDefaults.standard.string(forKey: "cliPath")) {
        self.containerPath = Self.resolvedContainerPath(configuredPath: configuredPath)
    }

    static func resolvedContainerPath(
        configuredPath: String?,
        fileManager: FileManager = .default
    ) -> String {
        let trimmedPath = configuredPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedPath,
           !trimmedPath.isEmpty,
           fileManager.isExecutableFile(atPath: trimmedPath) {
            return trimmedPath
        }

        return Self.findContainerPath(fileManager: fileManager) ?? "/usr/local/bin/container"
    }

    /// 查找 container 命令路径
    private static func findContainerPath(fileManager: FileManager = .default) -> String? {
        let paths = [
            "/usr/local/bin/container",
            "/opt/homebrew/bin/container",
            "/usr/bin/container",
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/container").path,
        ]

        for path in paths {
            if fileManager.isExecutableFile(atPath: path) {
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
            arguments: Self.systemStatusArguments()
        )

        return SystemInfo(
            version: "unknown",
            os: "macOS",
            kernel: "unknown",
            arch: ProcessInfo.processInfo.machineHardwareName,
            isServiceRunning: output.localizedCaseInsensitiveContains("running"),
            containersRunning: 0,
            containersStopped: 0,
            images: 0
        )
    }

    static func systemStatusArguments() -> [String] {
        ["system", "status"]
    }

    /// 获取容器列表
    func listContainers(all: Bool = true) async throws -> [Container] {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.listContainersArguments(all: all)
        )

        return try parseContainerList(from: output)
    }

    static func listContainersArguments(all: Bool, quiet: Bool = false, format: String = "json") -> [String] {
        var arguments = ["list", "--format", format]
        if all {
            arguments.append("--all")
        }
        if quiet {
            arguments.append("--quiet")
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
        let configuration = json["configuration"] as? [String: Any]
        let statusInfo = json["status"] as? [String: Any]
        let imageInfo = configuration?["image"] as? [String: Any]
        let resources = configuration?["resources"] as? [String: Any]
        let publishedPorts = configuration?["publishedPorts"] as? [[String: Any]]

        guard let id = json["id"] as? String
            ?? json["ID"] as? String
            ?? configuration?["id"] as? String
        else {
            return nil
        }

        let name = json["name"] as? String
            ?? json["Name"] as? String
            ?? configuration?["name"] as? String
            ?? configuration?["id"] as? String
            ?? id
        let image = json["image"] as? String
            ?? json["Image"] as? String
            ?? imageInfo?["reference"] as? String
            ?? ""
        let stateStr = statusInfo?["state"] as? String
            ?? json["state"] as? String
            ?? json["State"] as? String
            ?? ""
        let statusStr = statusInfo?["state"] as? String
            ?? json["status"] as? String
            ?? json["Status"] as? String
            ?? ""
        let created = configuration?["creationDate"] as? String
            ?? json["created"] as? String
            ?? json["CreatedAt"] as? String
            ?? ""
        let ports = Self.formatPublishedPorts(publishedPorts)
            ?? json["ports"] as? String
            ?? json["Ports"] as? String
            ?? ""
        let cpus = resources?["cpus"] as? Int
            ?? json["cpus"] as? Int
            ?? json["CPUs"] as? Int
            ?? 1
        let memory = json["memory"] as? String
            ?? json["Memory"] as? String
            ?? Self.formatMemory(resources?["memoryInBytes"])
            ?? "512 MB"

        let status = ContainerStatus(rawValue: statusStr.lowercased()) ?? .created
        let normalizedState = stateStr.lowercased() == "stopped" ? "exited" : stateStr.lowercased()
        let state = ContainerState(rawValue: normalizedState) ?? .created

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

    static func formatPublishedPorts(_ publishedPorts: [[String: Any]]?) -> String? {
        guard let publishedPorts, !publishedPorts.isEmpty else { return nil }

        let values = publishedPorts.compactMap { port -> String? in
            guard let containerPort = port["containerPort"] as? Int else {
                return nil
            }
            let hostPort = port["hostPort"] as? Int
            let proto = (port["proto"] as? String ?? "tcp").lowercased()

            if let hostPort {
                return "\(hostPort):\(containerPort)/\(proto)"
            }
            return "\(containerPort)/\(proto)"
        }

        return values.isEmpty ? nil : values.joined(separator: ", ")
    }

    static func formatMemory(_ rawValue: Any?) -> String? {
        let bytes: Int64?

        if let int64Value = rawValue as? Int64 {
            bytes = int64Value
        } else if let intValue = rawValue as? Int {
            bytes = Int64(intValue)
        } else if let doubleValue = rawValue as? Double {
            bytes = Int64(doubleValue)
        } else {
            bytes = nil
        }

        guard let bytes else { return nil }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
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
        let configuration = json["configuration"] as? [String: Any]
        let descriptor = configuration?["descriptor"] as? [String: Any]
        let variants = json["variants"] as? [[String: Any]]

        guard let id = json["id"] as? String ?? json["ID"] as? String else {
            return nil
        }

        let reference = configuration?["name"] as? String
            ?? json["repository"] as? String
            ?? json["Repository"] as? String
            ?? ""
        let (repository, tag) = Self.parseImageReference(reference)
        let size = Self.parseImageSize(variants: variants, descriptor: descriptor)
            ?? json["size"] as? Int64
            ?? json["Size"] as? Int64
            ?? 0
        let created = configuration?["creationDate"] as? String
            ?? json["created"] as? String
            ?? json["CreatedAt"] as? String
            ?? ""

        return Image(
            id: id,
            repository: repository,
            tag: tag,
            size: size,
            created: created
        )
    }

    static func parseImageReference(_ reference: String) -> (repository: String, tag: String) {
        guard !reference.isEmpty else { return ("<none>", "") }

        let referenceWithoutDigest = reference.split(separator: "@", maxSplits: 1).first.map(String.init) ?? reference
        let lastSlashIndex = referenceWithoutDigest.lastIndex(of: "/")
        let lastColonIndex = referenceWithoutDigest.lastIndex(of: ":")

        let repository: String
        let tag: String

        if let lastColonIndex,
           lastSlashIndex == nil || lastColonIndex > lastSlashIndex! {
            repository = String(referenceWithoutDigest[..<lastColonIndex])
            tag = String(referenceWithoutDigest[referenceWithoutDigest.index(after: lastColonIndex)...])
        } else {
            repository = referenceWithoutDigest
            tag = ""
        }

        if repository.hasPrefix("docker.io/library/") {
            return (String(repository.dropFirst("docker.io/library/".count)), tag)
        }
        if repository.hasPrefix("docker.io/") {
            return (String(repository.dropFirst("docker.io/".count)), tag)
        }

        return (repository, tag)
    }

    static func parseImageSize(variants: [[String: Any]]?, descriptor: [String: Any]?) -> Int64? {
        if let variants, !variants.isEmpty {
            let variantSize = variants.reduce(into: Int64(0)) { partialResult, variant in
                if let size = variant["size"] as? Int64 {
                    partialResult += size
                } else if let size = variant["size"] as? Int {
                    partialResult += Int64(size)
                }
            }
            if variantSize > 0 {
                return variantSize
            }
        }

        if let size = descriptor?["size"] as? Int64 {
            return size
        }
        if let size = descriptor?["size"] as? Int {
            return Int64(size)
        }
        return nil
    }

    /// 创建并启动容器
    func createContainer(config: ContainerConfig) async throws -> String {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.createContainerArguments(config: config)
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func createContainerArguments(config: ContainerConfig) -> [String] {
        var arguments = ["create"]

        if !config.name.isEmpty {
            arguments.append(contentsOf: ["--name", config.name])
        }

        arguments.append(contentsOf: ["--cpus", "\(config.cpus)"])
        arguments.append(contentsOf: ["--memory", config.memory])

        if !config.ports.isEmpty {
            arguments.append(contentsOf: ["--publish", config.ports])
        }

        if !config.dns.isEmpty {
            arguments.append(contentsOf: ["--dns", config.dns])
        }
        if !config.dnsDomain.isEmpty {
            arguments.append(contentsOf: ["--dns-domain", config.dnsDomain])
        }
        for dnsSearch in config.dnsSearch {
            arguments.append(contentsOf: ["--dns-search", dnsSearch])
        }
        for dnsOption in config.dnsOptions {
            arguments.append(contentsOf: ["--dns-option", dnsOption])
        }
        if config.noDNS {
            arguments.append("--no-dns")
        }

        for (key, value) in config.env {
            arguments.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        for envFile in config.envFiles {
            arguments.append(contentsOf: ["--env-file", envFile])
        }

        for volume in config.volumes {
            arguments.append(contentsOf: ["-v", volume])
        }
        for mount in config.mounts {
            arguments.append(contentsOf: ["--mount", mount])
        }
        for label in config.labels {
            arguments.append(contentsOf: ["--label", label])
        }
        for network in config.networks {
            arguments.append(contentsOf: ["--network", network])
        }

        if config.detach {
            arguments.append("--detach")
        }

        if config.interactive {
            arguments.append("--interactive")
        }

        if config.tty {
            arguments.append("--tty")
        }

        if config.autoRemove {
            arguments.append("--rm")
        }
        if !config.entrypoint.isEmpty {
            arguments.append(contentsOf: ["--entrypoint", config.entrypoint])
        }
        if !config.workdir.isEmpty {
            arguments.append(contentsOf: ["--workdir", config.workdir])
        }
        if !config.user.isEmpty {
            arguments.append(contentsOf: ["--user", config.user])
        }
        if !config.uid.isEmpty {
            arguments.append(contentsOf: ["--uid", config.uid])
        }
        if !config.gid.isEmpty {
            arguments.append(contentsOf: ["--gid", config.gid])
        }
        for ulimit in config.ulimits {
            arguments.append(contentsOf: ["--ulimit", ulimit])
        }
        if !config.platform.isEmpty {
            arguments.append(contentsOf: ["--platform", config.platform])
        }
        if !config.arch.isEmpty {
            arguments.append(contentsOf: ["--arch", config.arch])
        }
        if !config.os.isEmpty {
            arguments.append(contentsOf: ["--os", config.os])
        }
        if !config.kernel.isEmpty {
            arguments.append(contentsOf: ["--kernel", config.kernel])
        }
        if !config.runtime.isEmpty {
            arguments.append(contentsOf: ["--runtime", config.runtime])
        }
        if config.initProcess {
            arguments.append("--init")
        }
        if !config.initImage.isEmpty {
            arguments.append(contentsOf: ["--init-image", config.initImage])
        }
        if config.readOnly {
            arguments.append("--read-only")
        }
        if config.rosetta {
            arguments.append("--rosetta")
        }
        if config.ssh {
            arguments.append("--ssh")
        }
        if config.virtualization {
            arguments.append("--virtualization")
        }
        if !config.shmSize.isEmpty {
            arguments.append(contentsOf: ["--shm-size", config.shmSize])
        }
        for tmpfs in config.tmpfs {
            arguments.append(contentsOf: ["--tmpfs", tmpfs])
        }
        for cap in config.capAdd {
            arguments.append(contentsOf: ["--cap-add", cap])
        }
        for cap in config.capDrop {
            arguments.append(contentsOf: ["--cap-drop", cap])
        }
        if !config.scheme.isEmpty {
            arguments.append(contentsOf: ["--scheme", config.scheme])
        }
        if !config.maxConcurrentDownloads.isEmpty {
            arguments.append(contentsOf: ["--max-concurrent-downloads", config.maxConcurrentDownloads])
        }

        arguments.append(config.image)

        return arguments
    }

    /// 运行容器
    func runContainer(config: ContainerConfig, command: [String] = []) async throws -> String {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.runContainerArguments(config: config, command: command)
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func runContainerArguments(config: ContainerConfig, command: [String]) -> [String] {
        var arguments = createContainerArguments(config: config)
        arguments[0] = "run"
        arguments.append(contentsOf: command)
        return arguments
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

    static func removeContainerArguments(id: String? = nil, force: Bool, all: Bool = false) -> [String] {
        var arguments = ["delete"]
        if all {
            arguments.append("--all")
        }
        if force {
            arguments.append("--force")
        }
        if let id, !id.isEmpty {
            arguments.append(id)
        }
        return arguments
    }

    /// 查看容器详情
    func inspectContainers(ids: [String]) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.inspectContainerArguments(ids: ids))
    }

    static func inspectContainerArguments(ids: [String]) -> [String] {
        ["inspect"] + ids
    }

    /// 终止容器
    func killContainers(ids: [String], signal: String? = nil, all: Bool = false) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.killContainerArguments(ids: ids, signal: signal, all: all)
        )
    }

    static func killContainerArguments(ids: [String], signal: String?, all: Bool) -> [String] {
        var arguments = ["kill"]
        if all {
            arguments.append("--all")
        }
        if let signal, !signal.isEmpty {
            arguments.append(contentsOf: ["--signal", signal])
        }
        arguments.append(contentsOf: ids)
        return arguments
    }

    /// 清理已停止容器
    func pruneContainers() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.pruneContainersArguments())
    }

    static func pruneContainersArguments() -> [String] {
        ["prune"]
    }

    /// 导出容器文件系统
    func exportContainer(id: String, outputPath: String? = nil) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.exportContainerArguments(id: id, outputPath: outputPath)
        )
    }

    func exportContainer(
        id: String,
        outputPath: String? = nil,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws -> String {
        let result = try await executor.executeStreaming(
            containerPath,
            arguments: Self.exportContainerArguments(id: id, outputPath: outputPath),
            timeout: 900,
            onOutput: onProgress
        )
        return result.stdout
    }

    static func exportContainerArguments(id: String, outputPath: String?) -> [String] {
        var arguments = ["export"]
        if let outputPath, !outputPath.isEmpty {
            arguments.append(contentsOf: ["--output", outputPath])
        }
        arguments.append(id)
        return arguments
    }

    /// 复制容器与本机之间的文件
    func copyContainerPath(source: String, destination: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.copyContainerArguments(source: source, destination: destination)
        )
    }

    func copyContainerPath(
        source: String,
        destination: String,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: Self.copyContainerArguments(source: source, destination: destination),
            timeout: 900,
            onOutput: onProgress
        )
    }

    static func copyContainerArguments(source: String, destination: String) -> [String] {
        ["copy", source, destination]
    }

    /// 拉取镜像
    func pullImage(name: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["image", "pull", name]
        )
    }

    func pullImage(name: String, onProgress: @Sendable @escaping (String) -> Void) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: ["image", "pull", name],
            timeout: 900,
            onOutput: onProgress
        )
    }

    /// 删除镜像
    func removeImage(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: ["image", "delete", id]
        )
    }

    /// 查看镜像详情
    func inspectImages(references: [String]) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.inspectImageArguments(references: references))
    }

    static func inspectImageArguments(references: [String]) -> [String] {
        ["image", "inspect"] + references
    }

    /// 加载镜像归档
    func loadImage(inputPath: String? = nil, force: Bool = false) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.loadImageArguments(inputPath: inputPath, force: force)
        )
    }

    func loadImage(
        inputPath: String? = nil,
        force: Bool = false,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: Self.loadImageArguments(inputPath: inputPath, force: force),
            timeout: 900,
            onOutput: onProgress
        )
    }

    static func loadImageArguments(inputPath: String?, force: Bool) -> [String] {
        var arguments = ["image", "load"]
        if let inputPath, !inputPath.isEmpty {
            arguments.append(contentsOf: ["--input", inputPath])
        }
        if force {
            arguments.append("--force")
        }
        return arguments
    }

    /// 保存镜像归档
    func saveImages(references: [String], outputPath: String? = nil, platform: String? = nil) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.saveImageArguments(references: references, outputPath: outputPath, platform: platform)
        )
    }

    func saveImages(
        references: [String],
        outputPath: String? = nil,
        platform: String? = nil,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws -> String {
        let result = try await executor.executeStreaming(
            containerPath,
            arguments: Self.saveImageArguments(references: references, outputPath: outputPath, platform: platform),
            timeout: 900,
            onOutput: onProgress
        )
        return result.stdout
    }

    static func saveImageArguments(references: [String], outputPath: String?, platform: String?) -> [String] {
        var arguments = ["image", "save"]
        if let outputPath, !outputPath.isEmpty {
            arguments.append(contentsOf: ["--output", outputPath])
        }
        if let platform, !platform.isEmpty {
            arguments.append(contentsOf: ["--platform", platform])
        }
        arguments.append(contentsOf: references)
        return arguments
    }

    /// 标记镜像
    func tagImage(source: String, target: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.tagImageArguments(source: source, target: target)
        )
    }

    static func tagImageArguments(source: String, target: String) -> [String] {
        ["image", "tag", source, target]
    }

    /// 清理镜像
    func pruneImages(all: Bool = false) async throws {
        _ = try await executor.execute(containerPath, arguments: Self.pruneImagesArguments(all: all))
    }

    static func pruneImagesArguments(all: Bool) -> [String] {
        var arguments = ["image", "prune"]
        if all {
            arguments.append("--all")
        }
        return arguments
    }

    /// 推送镜像
    func pushImage(reference: String, platform: String? = nil) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.pushImageArguments(reference: reference, platform: platform)
        )
    }

    func pushImage(
        reference: String,
        platform: String? = nil,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: Self.pushImageArguments(reference: reference, platform: platform),
            timeout: 900,
            onOutput: onProgress
        )
    }

    static func pushImageArguments(reference: String, platform: String?) -> [String] {
        var arguments = ["image", "push"]
        if let platform, !platform.isEmpty {
            arguments.append(contentsOf: ["--platform", platform])
        }
        arguments.append(reference)
        return arguments
    }

    /// 构建镜像
    func buildImage(options: ImageBuildOptions) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.buildImageArguments(options: options),
            timeout: 900
        )
    }

    func buildImage(
        options: ImageBuildOptions,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: Self.buildImageArguments(options: options),
            timeout: 900,
            onOutput: onProgress
        )
    }

    static func buildImageArguments(options: ImageBuildOptions) -> [String] {
        var arguments = ["build"]
        if let dockerfilePath = options.dockerfilePath, !dockerfilePath.isEmpty {
            arguments.append(contentsOf: ["--file", dockerfilePath])
        }
        for tag in options.tags {
            arguments.append(contentsOf: ["--tag", tag])
        }
        if let platform = options.platform, !platform.isEmpty {
            arguments.append(contentsOf: ["--platform", platform])
        }
        if let dns = options.dns, !dns.isEmpty {
            arguments.append(contentsOf: ["--dns", dns])
        }
        for key in options.buildArgs.keys.sorted() {
            guard let value = options.buildArgs[key] else { continue }
            arguments.append(contentsOf: ["--build-arg", "\(key)=\(value)"])
        }
        if options.noCache {
            arguments.append("--no-cache")
        }
        if options.pull {
            arguments.append("--pull")
        }
        arguments.append(options.contextDirectory)
        return arguments
    }

    /// 执行容器命令
    func execCommand(containerId: String, command: [String]) async throws -> String {
        return try await executor.execute(
            containerPath,
            arguments: Self.execContainerArguments(containerId: containerId, command: command)
        )
    }

    static func execContainerArguments(containerId: String, command: [String]) -> [String] {
        ["exec", containerId] + command
    }

    func listContainerDirectory(containerId: String, path: String) async throws -> [ContainerFileEntry] {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.listContainerDirectoryArguments(containerId: containerId, path: path)
        )
        return Self.parseContainerDirectoryOutput(output)
    }

    static func listContainerDirectoryArguments(containerId: String, path: String) -> [String] {
        execContainerArguments(
            containerId: containerId,
            command: ["/bin/sh", "-lc", "LC_ALL=C ls -la \(shellQuote(path))"]
        )
    }

    func listMachineDirectory(machineId: String, path: String) async throws -> [ContainerFileEntry] {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.listMachineDirectoryArguments(machineId: machineId, path: path)
        )
        return Self.parseContainerDirectoryOutput(output)
    }

    static func listMachineDirectoryArguments(machineId: String, path: String) -> [String] {
        runMachineArguments(
            id: machineId,
            command: ["ls", "-la", path]
        )
    }

    static func parseContainerDirectoryOutput(_ output: String) -> [ContainerFileEntry] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> ContainerFileEntry? in
                let parts = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true).map(String.init)
                guard parts.count >= 9, parts[0] != "total", parts[8] != ".", parts[8] != ".." else { return nil }
                return ContainerFileEntry(
                    permissions: parts[0],
                    owner: parts[2],
                    group: parts[3],
                    size: parts[4],
                    modified: "\(parts[5]) \(parts[6]) \(parts[7])",
                    name: parts[8],
                    isDirectory: parts[0].hasPrefix("d")
                )
            }
    }

    private static func shellQuote(_ value: String) -> String {
        let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
        if value.rangeOfCharacter(from: safeCharacters.inverted) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// 获取容器日志（支持流式输出）
    func logs(containerId: String, follow: Bool = false, tail: Int? = nil) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.containerLogsArguments(containerId: containerId, follow: follow, tail: tail, boot: false)
        )
    }

    static func containerLogsArguments(containerId: String, follow: Bool, tail: Int?, boot: Bool) -> [String] {
        var arguments = ["logs"]
        if boot {
            arguments.append("--boot")
        }
        if follow {
            arguments.append("--follow")
        }
        if let tail {
            arguments.append(contentsOf: ["-n", "\(tail)"])
        }
        arguments.append(containerId)
        return arguments
    }

    /// 获取容器资源使用情况
    func stats(containerId: String) async throws -> ContainerStats {
        let output = try await executor.execute(
            containerPath,
            arguments: Self.statsArguments(containerId: containerId)
        )

        return try Self.parseStatsOutput(output, containerId: containerId)
    }

    static func statsArguments(containerId: String) -> [String] {
        ["stats", containerId, "--format", "json", "--no-stream"]
    }

    static func parseStatsOutput(_ output: String, containerId: String?) throws -> ContainerStats {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw CommandError.invalidOutput
        }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let statsJSON = selectStatsJSON(from: array, containerId: containerId) {
            return parseStatsJSON(statsJSON)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseStatsJSON(json)
        }

        throw CommandError.invalidOutput
    }

    private static func selectStatsJSON(from array: [[String: Any]], containerId: String?) -> [String: Any]? {
        guard !array.isEmpty else { return nil }
        guard let containerId, !containerId.isEmpty else { return array.first }
        return array.first(where: { ($0["id"] as? String) == containerId }) ?? array.first
    }

    private static func parseStatsJSON(_ json: [String: Any]) -> ContainerStats {
        let memoryUsageBytes = parseInt64(json["memoryUsageBytes"])
        let memoryLimitBytes = parseInt64(json["memoryLimitBytes"])
        let networkRxBytes = parseInt64(json["networkRxBytes"])
        let networkTxBytes = parseInt64(json["networkTxBytes"])
        let blockReadBytes = parseInt64(json["blockReadBytes"])
        let blockWriteBytes = parseInt64(json["blockWriteBytes"])

        let legacyMemoryUsage = json["memory_usage"] as? String
        let legacyMemoryLimit = json["memory_limit"] as? String
        let legacyNetworkIO = json["network_io"] as? String
        let legacyBlockIO = json["block_io"] as? String
        let legacyNetworkParts = splitStatsPair(legacyNetworkIO)
        let legacyBlockParts = splitStatsPair(legacyBlockIO)
        let legacyCPUPercent = parseDouble(json["cpu_percent"])
        let memoryPercent: Double = {
            if let legacy = parseDouble(json["memory_percent"]) {
                return legacy
            }
            guard memoryLimitBytes > 0 else { return 0 }
            return (Double(memoryUsageBytes) / Double(memoryLimitBytes)) * 100
        }()

        return ContainerStats(
            cpuPercent: legacyCPUPercent ?? 0,
            cpuUsageUsec: parseInt64(json["cpuUsageUsec"]),
            memoryUsage: legacyMemoryUsage ?? formatStatsBytes(memoryUsageBytes),
            memoryLimit: legacyMemoryLimit ?? formatStatsBytes(memoryLimitBytes),
            memoryPercent: memoryPercent,
            networkIO: legacyNetworkIO ?? "\(formatStatsBytes(networkRxBytes)) / \(formatStatsBytes(networkTxBytes))",
            networkRx: legacyNetworkParts.0 ?? formatStatsBytes(networkRxBytes),
            networkTx: legacyNetworkParts.1 ?? formatStatsBytes(networkTxBytes),
            blockIO: legacyBlockIO ?? "\(formatStatsBytes(blockReadBytes)) / \(formatStatsBytes(blockWriteBytes))",
            blockRead: legacyBlockParts.0 ?? formatStatsBytes(blockReadBytes),
            blockWrite: legacyBlockParts.1 ?? formatStatsBytes(blockWriteBytes),
            pids: (json["pids"] as? Int) ?? (json["numProcesses"] as? Int) ?? Int(parseInt64(json["numProcesses"]))
        )
    }

    private static func parseInt64(_ rawValue: Any?) -> Int64 {
        if let int64Value = rawValue as? Int64 {
            return int64Value
        }
        if let intValue = rawValue as? Int {
            return Int64(intValue)
        }
        if let doubleValue = rawValue as? Double {
            return Int64(doubleValue)
        }
        if let stringValue = rawValue as? String, let int64Value = Int64(stringValue) {
            return int64Value
        }
        return 0
    }

    private static func parseDouble(_ rawValue: Any?) -> Double? {
        if let doubleValue = rawValue as? Double {
            return doubleValue
        }
        if let intValue = rawValue as? Int {
            return Double(intValue)
        }
        if let int64Value = rawValue as? Int64 {
            return Double(int64Value)
        }
        if let stringValue = rawValue as? String {
            return Double(stringValue)
        }
        return nil
    }

    private static func formatStatsBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: max(0, bytes))
    }

    private static func splitStatsPair(_ value: String?) -> (String?, String?) {
        guard let value else { return (nil, nil) }
        let parts = value.components(separatedBy: " / ").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !parts.isEmpty else { return (nil, nil) }
        return (
            parts.indices.contains(0) ? parts[0] : nil,
            parts.indices.contains(1) ? parts[1] : nil
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

    /// 系统版本信息
    func systemVersion() async throws -> String {
        try await executor.execute(containerPath, arguments: Self.systemVersionArguments())
    }

    static func systemVersionArguments() -> [String] {
        ["system", "version"]
    }

    /// 系统磁盘用量
    func systemDiskUsage() async throws -> String {
        try await executor.execute(containerPath, arguments: Self.systemDiskUsageArguments())
    }

    static func systemDiskUsageArguments() -> [String] {
        ["system", "df"]
    }

    /// 系统日志
    func systemLogs(follow: Bool = false, last: String? = nil) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.systemLogsArguments(follow: follow, last: last))
    }

    static func systemLogsArguments(follow: Bool, last: String?) -> [String] {
        var arguments = ["system", "logs"]
        if follow {
            arguments.append("--follow")
        }
        if let last, !last.isEmpty {
            arguments.append(contentsOf: ["--last", last])
        }
        return arguments
    }

    /// 系统属性列表
    func systemPropertyList() async throws -> String {
        try await executor.execute(containerPath, arguments: Self.systemPropertyListArguments())
    }

    static func systemPropertyListArguments() -> [String] {
        ["system", "property", "list"]
    }

    func systemDNSList() async throws -> String {
        try await executor.execute(containerPath, arguments: Self.systemDNSListArguments())
    }

    static func systemDNSListArguments() -> [String] {
        ["system", "dns", "list"]
    }

    func systemDNSCreate(domain: String, localhost: String? = nil) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.systemDNSCreateArguments(domain: domain, localhost: localhost)
        )
    }

    static func systemDNSCreateArguments(domain: String, localhost: String?) -> [String] {
        var arguments = ["system", "dns", "create"]
        if let localhost, !localhost.isEmpty {
            arguments.append(contentsOf: ["--localhost", localhost])
        }
        arguments.append(domain)
        return arguments
    }

    func systemDNSDelete(domain: String) async throws {
        _ = try await executor.execute(containerPath, arguments: Self.systemDNSDeleteArguments(domain: domain))
    }

    static func systemDNSDeleteArguments(domain: String) -> [String] {
        ["system", "dns", "delete", domain]
    }

    func systemKernelSet(path: String) async throws {
        _ = try await executor.execute(containerPath, arguments: Self.systemKernelSetArguments(path: path))
    }

    static func systemKernelSetArguments(path: String) -> [String] {
        ["system", "kernel", "set", path]
    }

    func registryList() async throws -> String {
        try await executor.execute(containerPath, arguments: Self.registryListArguments())
    }

    static func registryListArguments() -> [String] {
        ["registry", "list"]
    }

    func registryLogin(server: String, username: String? = nil, scheme: String? = nil, passwordStdin: Bool = false) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.registryLoginArguments(server: server, username: username, scheme: scheme, passwordStdin: passwordStdin)
        )
    }

    static func registryLoginArguments(server: String, username: String?, scheme: String?, passwordStdin: Bool) -> [String] {
        var arguments = ["registry", "login"]
        if let scheme, !scheme.isEmpty {
            arguments.append(contentsOf: ["--scheme", scheme])
        }
        if passwordStdin {
            arguments.append("--password-stdin")
        }
        if let username, !username.isEmpty {
            arguments.append(contentsOf: ["--username", username])
        }
        arguments.append(server)
        return arguments
    }

    func registryLogout(server: String) async throws {
        _ = try await executor.execute(containerPath, arguments: Self.registryLogoutArguments(server: server))
    }

    static func registryLogoutArguments(server: String) -> [String] {
        ["registry", "logout", server]
    }

    func builderStatus(format: String? = nil) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.builderStatusArguments(format: format))
    }

    static func builderStatusArguments(format: String?) -> [String] {
        var arguments = ["builder", "status"]
        if let format, !format.isEmpty {
            arguments.append(contentsOf: ["--format", format])
        }
        return arguments
    }

    func builderStart() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.builderStartArguments())
    }

    static func builderStartArguments() -> [String] {
        ["builder", "start"]
    }

    func builderStop() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.builderStopArguments())
    }

    static func builderStopArguments() -> [String] {
        ["builder", "stop"]
    }

    func builderDelete() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.builderDeleteArguments())
    }

    static func builderDeleteArguments() -> [String] {
        ["builder", "rm"]
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
            return array.compactMap { item in
                item["name"] as? String
                    ?? (item["configuration"] as? [String: Any])?["name"] as? String
                    ?? item["id"] as? String
            }
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

    func inspectVolumes(names: [String]) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.inspectVolumeArguments(names: names))
    }

    static func inspectVolumeArguments(names: [String]) -> [String] {
        ["volume", "inspect"] + names
    }

    func pruneVolumes() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.pruneVolumesArguments())
    }

    static func pruneVolumesArguments() -> [String] {
        ["volume", "prune"]
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
        let configuration = json["configuration"] as? [String: Any]
        let status = json["status"] as? [String: Any]

        guard let id = json["id"] as? String ?? json["ID"] as? String,
              let name = json["name"] as? String
                ?? json["Name"] as? String
                ?? configuration?["name"] as? String
        else {
            return nil
        }

        let driver = json["driver"] as? String
            ?? json["Driver"] as? String
            ?? configuration?["mode"] as? String
            ?? configuration?["plugin"] as? String
            ?? "default"
        let scope = json["scope"] as? String
            ?? json["Scope"] as? String
            ?? "local"
        let ipamDriver = json["ipam_driver"] as? String
            ?? json["IPAMDriver"] as? String
            ?? "default"
        let subnet = json["subnet"] as? String
            ?? json["Subnet"] as? String
            ?? status?["ipv4Subnet"] as? String
            ?? status?["ipv6Subnet"] as? String
            ?? ""
        let gateway = json["gateway"] as? String
            ?? json["Gateway"] as? String
            ?? status?["ipv4Gateway"] as? String
            ?? ""
        let containers = json["containers"] as? Int
            ?? json["Containers"] as? Int
            ?? 0

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

        if !config.subnet.isEmpty {
            arguments += ["--subnet", config.subnet]
        }

        if config.isInternal {
            arguments.append("--internal")
        }

        if config.driver.hasPrefix("container-network-") {
            arguments += ["--plugin", config.driver]
        }

        if !config.name.isEmpty {
            arguments.append(config.name)
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

    func inspectNetworks(ids: [String]) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.inspectNetworkArguments(ids: ids))
    }

    static func inspectNetworkArguments(ids: [String]) -> [String] {
        ["network", "inspect"] + ids
    }

    func pruneNetworks() async throws {
        _ = try await executor.execute(containerPath, arguments: Self.pruneNetworksArguments())
    }

    static func pruneNetworksArguments() -> [String] {
        ["network", "prune"]
    }

    /// 连接容器到网络
    func connectNetwork(networkId: String, containerId: String) async throws {
        guard let arguments = Self.networkConnectArguments(networkId: networkId, containerId: containerId) else {
            throw CommandError.unsupportedCommand("container network connect")
        }

        _ = try await executor.execute(containerPath, arguments: arguments)
    }

    static func networkConnectArguments(networkId: String, containerId: String) -> [String]? {
        nil
    }

    /// 断开容器与网络的连接
    func disconnectNetwork(networkId: String, containerId: String) async throws {
        guard let arguments = Self.networkDisconnectArguments(networkId: networkId, containerId: containerId) else {
            throw CommandError.unsupportedCommand("container network disconnect")
        }

        _ = try await executor.execute(containerPath, arguments: arguments)
    }

    static func networkDisconnectArguments(networkId: String, containerId: String) -> [String]? {
        nil
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
            return array.compactMap { Self.parseMachine(from: $0) }
        }

        return []
    }

    /// 从 JSON 解析机器对象
    static func parseMachine(from json: [String: Any]) -> Machine? {
        let configuration = json["configuration"] as? [String: Any]
        let statusInfo = json["status"] as? [String: Any]

        guard let id = json["id"] as? String ?? json["ID"] as? String else {
            return nil
        }

        let name = json["name"] as? String
            ?? json["Name"] as? String
            ?? configuration?["name"] as? String
            ?? id

        let statusStr = statusInfo?["state"] as? String
            ?? json["status"] as? String
            ?? json["Status"] as? String
            ?? "stopped"
        let image = json["image"] as? String
            ?? json["Image"] as? String
            ?? configuration?["image"] as? String
            ?? ""
        let cpus = configuration?["cpus"] as? Int
            ?? json["cpus"] as? Int
            ?? json["CPUs"] as? Int
            ?? 2
        let memory = json["memory"] as? String
            ?? json["Memory"] as? String
            ?? Self.formatMemory(configuration?["memoryInBytes"])
            ?? "2 GB"
        let disk = json["disk"] as? String
            ?? json["Disk"] as? String
            ?? Self.formatMemory(configuration?["diskSizeInBytes"])
            ?? "20 GB"
        let ip = json["ipAddress"] as? String
            ?? statusInfo?["ipv4Address"] as? String
            ?? json["ip"] as? String
            ?? json["IP"] as? String
            ?? ""
        let created = configuration?["creationDate"] as? String
            ?? json["created"] as? String
            ?? json["CreatedAt"] as? String
            ?? ""

        let normalizedStatus = statusStr.prefix(1).uppercased() + statusStr.dropFirst().lowercased()
        let status = MachineStatus(rawValue: normalizedStatus) ?? .stopped

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
        _ = try await executor.execute(
            containerPath,
            arguments: Self.createMachineArguments(config: config),
            timeout: 900
        )
    }

    func createMachine(
        config: MachineConfig,
        onProgress: @Sendable @escaping (String) -> Void
    ) async throws {
        _ = try await executor.executeStreaming(
            containerPath,
            arguments: Self.createMachineArguments(config: config),
            timeout: 900,
            onOutput: onProgress
        )
    }

    static func createMachineArguments(config: MachineConfig) -> [String] {
        var arguments = ["machine", "create"]

        if !config.name.isEmpty {
            arguments += ["--name", config.name]
        }

        arguments += ["--cpus", "\(config.cpus)"]
        arguments += ["--memory", config.memory]
        if !config.homeMount.isEmpty {
            arguments += ["--home-mount", config.homeMount]
        }
        if config.setDefault {
            arguments.append("--set-default")
        }
        if config.noBoot {
            arguments.append("--no-boot")
        }
        arguments.append(config.image)

        return arguments
    }

    /// 启动机器
    func startMachine(id: String) async throws {
        do {
            _ = try await executor.execute(
                containerPath,
                arguments: Self.bootMachineArguments(id: id)
            )
        } catch {
            guard Self.isMachineBootRace(error) else {
                throw error
            }
        }

        try await waitForMachineToReachRunning(id: id)
    }

    static func bootMachineArguments(id: String) -> [String] {
        ["machine", "run", "--name", id, "--detach", "/bin/sleep", "infinity"]
    }

    static func runMachineArguments(id: String, command: [String]) -> [String] {
        var arguments = ["machine", "run", "--name", id]
        if !command.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: command)
        }
        return arguments
    }

    private static func isMachineBootRace(_ error: Error) -> Bool {
        let text = String(describing: error) + "\n" + error.localizedDescription
        return text.localizedCaseInsensitiveContains("cannot exec: container is not running")
    }

    private func waitForMachineToReachRunning(id: String, timeout: TimeInterval = 20) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let machines = try await listMachines()
            if let machine = machines.first(where: { $0.id == id || $0.name == id }),
               machine.status == .running {
                return
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        throw CommandError.commandFailed(
            1,
            "Timed out waiting for machine \(id) to reach the running state."
        )
    }

    /// 停止机器
    func stopMachine(id: String) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.stopMachineArguments(id: id)
        )
    }

    static func stopMachineArguments(id: String) -> [String] {
        ["machine", "stop", id]
    }

    /// 删除机器
    func removeMachine(id: String, force: Bool = false) async throws {
        let arguments = Self.removeMachineArguments(id: id, force: force)

        _ = try await executor.execute(
            containerPath,
            arguments: arguments
        )
    }

    static func removeMachineArguments(id: String, force: Bool) -> [String] {
        // 当前 Apple container 的 machine rm/delete 不支持 --force。
        ["machine", "rm", id]
    }

    /// 重启机器
    func restartMachine(id: String) async throws {
        try await stopMachine(id: id)
        try await startMachine(id: id)
    }

    func inspectMachine(id: String? = nil) async throws -> String {
        try await executor.execute(containerPath, arguments: Self.inspectMachineArguments(id: id))
    }

    static func inspectMachineArguments(id: String?) -> [String] {
        var arguments = ["machine", "inspect"]
        if let id, !id.isEmpty {
            arguments.append(id)
        }
        return arguments
    }

    func runMachine(id: String, command: [String]) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.runMachineArguments(id: id, command: command),
            timeout: 900
        )
    }

    func machineLogs(id: String? = nil, follow: Bool = false, tail: Int? = nil, boot: Bool = false) async throws -> String {
        try await executor.execute(
            containerPath,
            arguments: Self.machineLogsArguments(id: id, follow: follow, tail: tail, boot: boot)
        )
    }

    static func machineLogsArguments(id: String?, follow: Bool, tail: Int?, boot: Bool) -> [String] {
        var arguments = ["machine", "logs"]
        if boot {
            arguments.append("--boot")
        }
        if follow {
            arguments.append("--follow")
        }
        if let tail {
            arguments.append(contentsOf: ["-n", "\(tail)"])
        }
        if let id, !id.isEmpty {
            arguments.append(id)
        }
        return arguments
    }

    func setMachine(id: String, cpus: Int? = nil, memory: String? = nil, homeMount: String? = nil) async throws {
        _ = try await executor.execute(
            containerPath,
            arguments: Self.setMachineArguments(id: id, cpus: cpus, memory: memory, homeMount: homeMount)
        )
    }

    static func setMachineArguments(id: String, cpus: Int?, memory: String?, homeMount: String?) -> [String] {
        var arguments = ["machine", "set", "--name", id]
        if let cpus {
            arguments.append("cpus=\(cpus)")
        }
        if let memory, !memory.isEmpty {
            arguments.append("memory=\(memory)")
        }
        if let homeMount, !homeMount.isEmpty {
            arguments.append("home-mount=\(homeMount)")
        }
        return arguments
    }

    func setDefaultMachine(id: String) async throws {
        _ = try await executor.execute(containerPath, arguments: Self.setDefaultMachineArguments(id: id))
    }

    static func setDefaultMachineArguments(id: String) -> [String] {
        ["machine", "set-default", id]
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}
