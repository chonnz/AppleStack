import Foundation

/// 容器服务后端类型
enum ServiceBackendType {
    /// CLI 后端 - 通过 container 命令交互
    case cli

    /// 框架后端 - 直接使用 Containerization 框架（需要 macOS 26+）
    case framework
}

/// 容器服务工厂，根据系统环境创建合适的后端
struct ContainerServiceFactory {
    /// 创建容器服务实例
    /// - Parameter backend: 指定的后端类型，nil 时自动选择
    /// - Returns: 符合 ContainerServiceProtocol 的实例
    static func create(backend: ServiceBackendType? = nil) -> ContainerServiceProtocol {
        if let backend = backend {
            return createBackend(backend)
        }

        // 自动选择：检查是否支持框架后端
        if #available(macOS 26, *) {
            // TODO: 实现 FrameworkBackend
            // return FrameworkBackend()
            return CLIBackend()
        } else {
            return CLIBackend()
        }
    }

    /// 根据类型创建后端实例
    private static func createBackend(_ type: ServiceBackendType) -> ContainerServiceProtocol {
        switch type {
        case .cli:
            return CLIBackend()
        case .framework:
            if #available(macOS 26, *) {
                // TODO: 实现 FrameworkBackend
                // return FrameworkBackend()
                fatalError("FrameworkBackend 尚未实现")
            } else {
                fatalError("FrameworkBackend 需要 macOS 26 或更高版本")
            }
        }
    }
}
