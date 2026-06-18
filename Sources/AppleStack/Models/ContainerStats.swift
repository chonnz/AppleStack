import Foundation

/// 容器资源使用统计
struct ContainerStats {
    let cpuPercent: Double
    let cpuUsageUsec: Int64
    let memoryUsage: String
    let memoryLimit: String
    let memoryPercent: Double
    let networkIO: String
    let networkRx: String
    let networkTx: String
    let blockIO: String
    let blockRead: String
    let blockWrite: String
    let pids: Int

    /// CPU 使用率（格式化）
    var cpuFormatted: String {
        String(format: "%.2f%%", cpuPercent)
    }

    /// 内存使用率（格式化）
    var memoryFormatted: String {
        String(format: "%.2f%%", memoryPercent)
    }

    func withCPUPercent(_ value: Double) -> ContainerStats {
        ContainerStats(
            cpuPercent: value,
            cpuUsageUsec: cpuUsageUsec,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            memoryPercent: memoryPercent,
            networkIO: networkIO,
            networkRx: networkRx,
            networkTx: networkTx,
            blockIO: blockIO,
            blockRead: blockRead,
            blockWrite: blockWrite,
            pids: pids
        )
    }

    func resolvedCPUPercent(previousUsageUsec: Int64?, previousTimestamp: Date?, currentTimestamp: Date) -> Double {
        guard let previousUsageUsec,
              let previousTimestamp
        else {
            return cpuPercent
        }

        let elapsedSeconds = currentTimestamp.timeIntervalSince(previousTimestamp)
        guard elapsedSeconds > 0 else { return cpuPercent }

        let cpuDeltaUsec = max(0, cpuUsageUsec - previousUsageUsec)
        let cpuPercent = (Double(cpuDeltaUsec) / (elapsedSeconds * 1_000_000)) * 100
        return max(0, cpuPercent)
    }
}
