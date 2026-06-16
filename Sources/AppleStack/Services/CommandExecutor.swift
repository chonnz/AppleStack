import Foundation

/// 超时状态包装，用于跨并发上下文安全共享
private final class TimeoutState: @unchecked Sendable {
    var didTimeout = false
}

/// 命令执行器，负责执行系统命令并处理超时
actor CommandExecutor {
    /// 默认超时时间（秒）
    static let defaultTimeout: TimeInterval = 30

    /// 执行命令并返回输出
    func execute(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval = CommandExecutor.defaultTimeout
    ) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 设置进程环境
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
        } catch {
            throw CommandError.executionFailed(error.localizedDescription)
        }

        // 设置超时监控
        let timeoutState = TimeoutState()
        let pid = process.processIdentifier
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(Int(timeout)))
            if process.isRunning {
                timeoutState.didTimeout = true
                // 发送 SIGTERM 终止进程
                kill(pid, SIGTERM)
                try await Task.sleep(for: .seconds(2))
                if process.isRunning {
                    // 强制终止
                    kill(pid, SIGKILL)
                }
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        // 检查是否因超时终止
        if timeoutState.didTimeout {
            throw CommandError.timeout
        }

        // 检查进程退出状态
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.commandFailed(
                process.terminationStatus,
                errorOutput
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    /// 执行命令并返回结构化输出
    func executeWithResult(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval = CommandExecutor.defaultTimeout
    ) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
        } catch {
            throw CommandError.executionFailed(error.localizedDescription)
        }

        let timeoutState = TimeoutState()
        let pid = process.processIdentifier
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(Int(timeout)))
            if process.isRunning {
                timeoutState.didTimeout = true
                kill(pid, SIGTERM)
                try await Task.sleep(for: .seconds(2))
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        if timeoutState.didTimeout {
            throw CommandError.timeout
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: String(data: errorData, encoding: .utf8) ?? ""
        )
    }
}

/// 命令执行结果
struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var isSuccess: Bool { exitCode == 0 }
}

/// 命令执行错误
enum CommandError: Error, LocalizedError {
    case executionFailed(String)
    case commandFailed(Int32, String)
    case timeout
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .commandFailed(let code, let message):
            return "命令失败 (退出码 \(code)): \(message)"
        case .timeout:
            return "命令执行超时"
        case .invalidOutput:
            return "命令输出格式无效"
        }
    }
}
