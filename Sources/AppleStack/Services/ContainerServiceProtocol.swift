import Foundation

/// 容器服务协议，定义与容器运行时交互的接口
protocol ContainerServiceProtocol {
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

    /// 拉取镜像
    func pullImage(name: String) async throws

    /// 删除镜像
    func removeImage(id: String) async throws

    /// 执行容器命令
    func execCommand(containerId: String, command: [String]) async throws -> String

    /// 启动系统
    func systemStart() async throws

    /// 停止系统
    func systemStop() async throws

    /// 获取容器日志
    func logs(containerId: String, follow: Bool, tail: Int?) async throws -> String

    /// 获取容器资源使用情况
    func stats(containerId: String) async throws -> ContainerStats
}
