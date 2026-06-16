import Foundation
import SwiftUI

/// 日志流视图模型
@Observable
final class LogStreamViewModel: @unchecked Sendable {
    var logs: [LogEntry] = []
    var isLoading = false
    var isStreaming = false
    var errorMessage: String?
    var autoScroll = true

    private let service: ContainerServiceProtocol
    private let containerId: String
    private var streamTask: Task<Void, Never>?

    init(service: ContainerServiceProtocol, containerId: String) {
        self.service = service
        self.containerId = containerId
    }

    /// 加载历史日志
    func loadLogs(tail: Int = 500) async {
        isLoading = true
        errorMessage = nil

        do {
            let output = try await service.logs(containerId: containerId, follow: false, tail: tail)
            let lines = output.components(separatedBy: .newlines)
            logs = lines.filter { !$0.isEmpty }.map { LogEntry(content: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 开始流式获取日志
    func startStreaming() {
        guard !isStreaming else { return }

        isStreaming = true
        streamTask = Task { [weak self] in
            guard let self else { return }

            do {
                let output = try await self.service.logs(containerId: self.containerId, follow: true, tail: nil)
                let lines = output.components(separatedBy: .newlines)

                for line in lines where !line.isEmpty {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self.logs.append(LogEntry(content: line))
                        // 限制日志数量
                        if self.logs.count > 10000 {
                            self.logs.removeFirst(1000)
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isStreaming = false
                    }
                }
            }
        }
    }

    /// 停止流式获取
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    /// 清空日志
    func clearLogs() {
        logs.removeAll()
    }

    /// 导出日志
    func exportLogs() -> String {
        logs.map(\.content).joined(separator: "\n")
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let content: String
    let timestamp = Date()

    /// 格式化时间戳
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
