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

    /// 查看容器详情
    func inspectContainers(ids: [String]) async throws -> String

    /// 终止容器
    func killContainers(ids: [String], signal: String?, all: Bool) async throws

    /// 清理已停止容器
    func pruneContainers() async throws

    /// 导出容器文件系统
    func exportContainer(id: String, outputPath: String?) async throws -> String

    /// 复制容器与本机之间的文件
    func copyContainerPath(source: String, destination: String) async throws

    /// 拉取镜像
    func pullImage(name: String) async throws

    /// 删除镜像
    func removeImage(id: String) async throws

    /// 查看镜像详情
    func inspectImages(references: [String]) async throws -> String

    /// 加载镜像归档
    func loadImage(inputPath: String?, force: Bool) async throws

    /// 保存镜像归档
    func saveImages(references: [String], outputPath: String?, platform: String?) async throws -> String

    /// 标记镜像
    func tagImage(source: String, target: String) async throws

    /// 清理镜像
    func pruneImages(all: Bool) async throws

    /// 推送镜像
    func pushImage(reference: String, platform: String?) async throws

    /// 构建镜像
    func buildImage(options: ImageBuildOptions) async throws -> String

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

    /// 获取容器日志
    func logs(containerId: String, follow: Bool, tail: Int?) async throws -> String

    /// 获取容器资源使用情况
    func stats(containerId: String) async throws -> ContainerStats
}
