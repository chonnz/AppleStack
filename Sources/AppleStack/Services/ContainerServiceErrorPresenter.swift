import Foundation

enum ContainerServiceErrorPresenter {
    static func isServiceNotRunning(_ error: Error) -> Bool {
        let text = String(describing: error) + "\n" + (error.localizedDescription)
        return text.localizedCaseInsensitiveContains("container system start") ||
            text.localizedCaseInsensitiveContains("XPC connection error") ||
            text.localizedCaseInsensitiveContains("apiserver is not running")
    }

    static func message(for error: Error) -> String {
        if isServiceNotRunning(error) {
            return "Container system service is not running. Click Start System or run `container system start`."
        }
        if isCLINotFound(error) {
            return "Apple container CLI not found. Install Apple container first, or configure the executable path in Settings > CLI."
        }
        return error.localizedDescription
    }

    private static func isCLINotFound(_ error: Error) -> Bool {
        guard case CommandError.executionFailed(let message) = error else {
            return false
        }
        let text = message + "\n" + error.localizedDescription
        return text.localizedCaseInsensitiveContains("no such file") ||
            text.localizedCaseInsensitiveContains("couldn’t be opened") ||
            text.localizedCaseInsensitiveContains("couldn't be opened") ||
            text.localizedCaseInsensitiveContains("not found")
    }

    static func machineImageBuildMessage(
        for error: Error,
        buildLog: String,
        dockerfilePath: String?,
        contextDirectory: String
    ) -> String {
        let baseMessage = message(for: error)
        let combined = "\(baseMessage)\n\(buildLog)"
        let lowercased = combined.lowercased()
        let trimmedLog = buildLog.trimmingCharacters(in: .whitespacesAndNewlines)
        let logSuffix = trimmedLog.isEmpty ? "" : "\n\nBuild logs:\n\(trimmedLog)"

        if lowercased.contains("temporary failure resolving") ||
            lowercased.contains("could not resolve") ||
            lowercased.contains("name or service not known") {
            return "系统环境准备失败。\n\n日志显示准备阶段无法解析域名，通常是 DNS 配置问题。请确认 `DNS nameserver` 已填写可用地址，例如 `8.8.8.8`，然后重试。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        if lowercased.contains("unable to locate package") {
            return "系统环境准备失败。\n\n基础系统里的包索引或软件源不可用，`apt-get` 无法找到需要的包。请先检查 `apt-get update` 是否成功，再确认模板里的包名是否存在。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        if lowercased.contains("systemctl: not found") || lowercased.contains("/bin/sh: 1: systemctl: not found") {
            return "系统环境准备失败。\n\n当前基础系统内没有可用的 `systemctl`，说明它还不具备完整启动环境。请优先使用 Ubuntu 这类支持 systemd 的基础系统。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        if lowercased.contains("no such file or directory") ||
            lowercased.contains("failed to read dockerfile") ||
            lowercased.contains("cannot find") {
            let fileDescription = (dockerfilePath?.isEmpty == false ? dockerfilePath! : "Containerfile")
            return "系统环境准备失败。\n\n未找到构建文件或上下文目录。请确认 `Context directory` 指向正确目录，并且 `\(fileDescription)` 已经写入到该目录中。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        if lowercased.contains("permission denied") {
            return "系统环境准备失败。\n\n准备过程遇到了文件权限问题。请确认 `Context directory` 和构建文件可读，且当前用户对该目录具有访问权限。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        if lowercased.contains("命令执行超时") || lowercased.contains("timed out") {
            if lowercased.contains("apt-get") || lowercased.contains("fetch") || lowercased.contains("download") {
                return "系统环境准备超时。\n\n长时间停留在拉取系统组件或安装软件包阶段，通常与网络速度、DNS 或软件源可用性有关。请检查网络后重试，必要时保留当前日志继续排查。\n\nContext: \(contextDirectory)\(logSuffix)"
            }
            return "系统环境准备超时。\n\n准备步骤在预期时间内没有完成。请根据日志确认卡在拉取系统组件、安装软件包还是系统设置步骤。\n\nContext: \(contextDirectory)\(logSuffix)"
        }

        return "系统环境准备失败。\n\n\(baseMessage)\n\nContext: \(contextDirectory)\(logSuffix)"
    }

    static func machineCreateMessage(
        for error: Error,
        createLog: String,
        machineName: String
    ) -> String {
        let baseMessage = message(for: error)
        let trimmedLog = createLog.trimmingCharacters(in: .whitespacesAndNewlines)
        let logSuffix = trimmedLog.isEmpty ? "" : "\n\nCreate logs:\n\(trimmedLog)"
        return "虚拟机 \(machineName) 创建失败。\n\n\(baseMessage)\(logSuffix)"
    }
}
