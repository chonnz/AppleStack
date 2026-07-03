import Foundation

/// 容器服务协议，定义与容器运行时交互的接口
protocol ContainerServiceProtocol: Sendable {
    /// 获取系统信息
    func getSystemInfo() async throws -> SystemInfo

    /// 获取容器列表
    func listContainers(all: Bool) async throws -> [Container]

    /// 获取镜像列表
    func listImages() async throws -> [Image]

    /// 创建并启动容器
    func createContainer(config: ContainerConfig) async throws -> String

    /// 停止容器
    func stopContainer(id: String) async throws

    /// 启动容器
    func startContainer(id: String) async throws

    /// 删除容器
    func removeContainer(id: String, force: Bool) async throws

    /// 运行容器
    func runContainer(config: ContainerConfig, command: [String]) async throws -> String

    /// 获取网络列表
    func listNetworks() async throws -> [Network]

    /// 创建网络
    func createNetwork(config: NetworkConfig) async throws

    /// 删除网络
    func removeNetwork(id: String) async throws

    /// 查看网络详情
    func inspectNetworks(ids: [String]) async throws -> String

    /// 清理未使用网络
    func pruneNetworks() async throws

    /// 获取卷列表
    func listVolumes() async throws -> [String]

    /// 创建卷
    func createVolume(name: String) async throws

    /// 删除卷
    func removeVolume(name: String) async throws

    /// 查看卷详情
    func inspectVolumes(names: [String]) async throws -> String

    /// 清理未使用卷
    func pruneVolumes() async throws

    /// 获取虚拟机列表
    func listMachines() async throws -> [Machine]

    /// 创建虚拟机
    func createMachine(config: MachineConfig) async throws

    /// 流式创建虚拟机
    func createMachine(config: MachineConfig, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 启动虚拟机
    func startMachine(id: String) async throws

    /// 停止虚拟机
    func stopMachine(id: String) async throws

    /// 删除虚拟机
    func removeMachine(id: String, force: Bool) async throws

    /// 查看虚拟机详情
    func inspectMachine(id: String?) async throws -> String

    /// 获取虚拟机日志
    func machineLogs(id: String?, follow: Bool, tail: Int?, boot: Bool) async throws -> String

    /// 列出虚拟机内目录
    func listMachineDirectory(machineId: String, path: String) async throws -> [ContainerFileEntry]

    /// 配置虚拟机资源
    func setMachine(id: String, cpus: Int?, memory: String?, homeMount: String?) async throws

    /// 设置默认虚拟机
    func setDefaultMachine(id: String) async throws

    /// 查看容器详情
    func inspectContainers(ids: [String]) async throws -> String

    /// 列出容器内目录
    func listContainerDirectory(containerId: String, path: String) async throws -> [ContainerFileEntry]

    /// 终止容器
    func killContainers(ids: [String], signal: String?, all: Bool) async throws

    /// 清理已停止容器
    func pruneContainers() async throws

    /// 导出容器文件系统
    func exportContainer(id: String, outputPath: String?) async throws -> String

    /// 流式导出容器文件系统
    func exportContainer(id: String, outputPath: String?, onProgress: @Sendable @escaping (String) -> Void) async throws -> String

    /// 复制容器与本机之间的文件
    func copyContainerPath(source: String, destination: String) async throws

    /// 流式复制容器与本机之间的文件
    func copyContainerPath(source: String, destination: String, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 拉取镜像
    func pullImage(name: String) async throws

    /// 流式拉取镜像
    func pullImage(name: String, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 删除镜像
    func removeImage(id: String) async throws

    /// 查看镜像详情
    func inspectImages(references: [String]) async throws -> String

    /// 加载镜像归档
    func loadImage(inputPath: String?, force: Bool) async throws

    /// 流式加载镜像归档
    func loadImage(inputPath: String?, force: Bool, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 保存镜像归档
    func saveImages(references: [String], outputPath: String?, platform: String?) async throws -> String

    /// 流式保存镜像归档
    func saveImages(references: [String], outputPath: String?, platform: String?, onProgress: @Sendable @escaping (String) -> Void) async throws -> String

    /// 标记镜像
    func tagImage(source: String, target: String) async throws

    /// 清理镜像
    func pruneImages(all: Bool) async throws

    /// 推送镜像
    func pushImage(reference: String, platform: String?) async throws

    /// 流式推送镜像
    func pushImage(reference: String, platform: String?, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 构建镜像
    func buildImage(options: ImageBuildOptions) async throws -> String

    /// 流式构建镜像
    func buildImage(options: ImageBuildOptions, onProgress: @Sendable @escaping (String) -> Void) async throws

    /// 执行容器命令
    func execCommand(containerId: String, command: [String]) async throws -> String

    /// 启动系统
    func systemStart() async throws

    /// 停止系统
    func systemStop() async throws

    /// 系统版本信息
    func systemVersion() async throws -> String

    /// 系统磁盘用量
    func systemDiskUsage() async throws -> String

    /// 系统日志
    func systemLogs(follow: Bool, last: String?) async throws -> String

    /// 系统属性列表
    func systemPropertyList() async throws -> String

    /// 系统 DNS 配置列表
    func systemDNSList() async throws -> String

    /// 创建系统 DNS 域
    func systemDNSCreate(domain: String, localhost: String?) async throws

    /// 删除系统 DNS 域
    func systemDNSDelete(domain: String) async throws

    /// 设置系统内核
    func systemKernelSet(path: String) async throws

    /// 获取容器日志
    func logs(containerId: String, follow: Bool, tail: Int?) async throws -> String

    /// 获取容器资源使用情况
    func stats(containerId: String) async throws -> ContainerStats

    // MARK: - Registry

    func registryList() async throws -> String

    func registryLogin(server: String, username: String?, scheme: String?, passwordStdin: Bool) async throws

    func registryLogout(server: String) async throws

    // MARK: - Builder

    func builderStatus(format: String?) async throws -> String

    func builderStart() async throws

    func builderStop() async throws

    func builderDelete() async throws
}
