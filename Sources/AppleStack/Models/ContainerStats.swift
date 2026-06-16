import Foundation

/// 容器资源使用统计
struct ContainerStats {
    let cpuPercent: Double
    let memoryUsage: String
    let memoryLimit: String
    let memoryPercent: Double
    let networkIO: String
    let blockIO: String
    let pids: Int

    /// CPU 使用率（格式化）
    var cpuFormatted: String {
        String(format: "%.2f%%", cpuPercent)
    }

    /// 内存使用率（格式化）
    var memoryFormatted: String {
        String(format: "%.2f%%", memoryPercent)
    }
}
