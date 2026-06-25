import Foundation

@MainActor
final class PersistentTerminalSession: ObservableObject {
    enum Target: Equatable {
        case container(id: String)
        case machine(id: String)

        var launchArguments: [String] {
            switch self {
            case .container(let id):
                ["exec", "--interactive", id, "/bin/sh"]
            case .machine(let id):
                ["machine", "run", "--name", id, "--interactive", "--", "/bin/sh"]
            }
        }

        var usesOneShotCommands: Bool {
            switch self {
            case .container:
                return false
            case .machine:
                return true
            }
        }

        func oneShotArguments(command: String) -> [String] {
            switch self {
            case .container(let id):
                return ["exec", id, "/bin/sh", "-lc", command]
            case .machine(let id):
                return ["machine", "run", "--name", id, "--", "/bin/sh", "-lc", command]
            }
        }

        var persistenceKey: String {
            switch self {
            case .container(let id):
                return "container.\(id)"
            case .machine(let id):
                return "machine.\(id)"
            }
        }

        func externalTerminalCommand(executableName: String = "container") -> String {
            ([executableName] + launchArguments)
                .map(Self.shellQuoted)
                .joined(separator: " ")
        }

        private static func shellQuoted(_ value: String) -> String {
            let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
            if value.rangeOfCharacter(from: safeCharacters.inverted) == nil {
                return value
            }

            return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
    }

    @Published private(set) var transcript = ""
    @Published private(set) var commandHistory: [String] = []
    @Published private(set) var isConnected = false
    @Published private(set) var isLaunching = false
    @Published private(set) var isExecutingCommand = false
    @Published private(set) var lastError: String?

    let target: Target

    private let commandExecutor = CommandExecutor()
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private static let transcriptPrefix = "appleStack.terminal.transcript."
    private static let historyPrefix = "appleStack.terminal.history."
    private static let maxTranscriptCharacters = 120_000
    private static let maxHistoryEntries = 100

    init(target: Target) {
        self.target = target
        loadPersistedState()
    }

    deinit {
        let process = process
        let stdinPipe = stdinPipe
        let stdoutPipe = stdoutPipe
        let stderrPipe = stderrPipe

        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }

    func activateIfNeeded() {
        guard process == nil, !isLaunching else { return }
        if target.usesOneShotCommands {
            isConnected = true
            isLaunching = false
            lastError = nil
            return
        }

        guard let executablePath = Self.findContainerPath() else {
            lastError = "未找到 `container` 命令。"
            return
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = target.launchArguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        process.environment = environment

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            Task { @MainActor [weak self] in
                self?.appendOutput(data)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            Task { @MainActor [weak self] in
                self?.appendOutput(data)
            }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                self?.stdinPipe?.fileHandleForWriting.closeFile()
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
                self?.stdinPipe = nil
                self?.stdoutPipe = nil
                self?.stderrPipe = nil
                self?.isConnected = false
                self?.isLaunching = false
                if process.terminationStatus != 0 {
                    self?.appendText("\n[session exited with code \(process.terminationStatus)]\n")
                }
            }
        }

        isLaunching = true
        lastError = nil

        do {
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            self.isConnected = true
            self.isLaunching = false
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            self.isLaunching = false
            self.lastError = error.localizedDescription
        }
    }

    func send(command: String) async throws {
        guard isConnected else {
            throw CommandError.executionFailed("终端会话尚未连接。")
        }

        if target.usesOneShotCommands {
            guard !isExecutingCommand else {
                throw CommandError.executionFailed("上一条命令仍在执行。")
            }
            guard let executablePath = Self.findContainerPath() else {
                throw CommandError.executionFailed("未找到 `container` 命令。")
            }

            isExecutingCommand = true
            defer { isExecutingCommand = false }

            do {
                let output = try await commandExecutor.execute(
                    executablePath,
                    arguments: target.oneShotArguments(command: command),
                    timeout: 120
                )
                appendText(output)
                if !output.hasSuffix("\n") {
                    appendText("\n")
                }
            } catch {
                lastError = error.localizedDescription
                throw error
            }
            return
        }

        guard let fileHandle = stdinPipe?.fileHandleForWriting else {
            throw CommandError.executionFailed("终端输入通道不可用。")
        }

        let line = command + "\n"
        guard let data = line.data(using: .utf8) else {
            throw CommandError.executionFailed("无法编码终端命令。")
        }

        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            throw CommandError.executionFailed(error.localizedDescription)
        }
    }

    func clearTranscript() {
        objectWillChange.send()
        transcript = ""
        persistState()
    }

    func appendLocalEcho(_ text: String) {
        objectWillChange.send()
        transcript += text
        trimTranscriptIfNeeded()
        persistState()
    }

    func recordSubmittedCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if commandHistory.last != trimmed {
            commandHistory.append(trimmed)
            if commandHistory.count > Self.maxHistoryEntries {
                commandHistory.removeFirst(commandHistory.count - Self.maxHistoryEntries)
            }
            persistState()
        }
    }

    func close() {
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isConnected = false
        isLaunching = false
        isExecutingCommand = false
    }

    func openInMacTerminal() throws {
        let command = target.externalTerminalCommand(executableName: Self.findContainerPath() ?? "container")
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"Terminal\"",
            "-e", "activate",
            "-e", "do script \"\(escapedCommand)\"",
            "-e", "end tell",
        ]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw CommandError.executionFailed(message?.isEmpty == false ? message! : "无法打开 macOS 终端。")
        }
    }

    private func appendOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        objectWillChange.send()
        transcript += text
        trimTranscriptIfNeeded()
        persistState()
    }

    private func appendText(_ text: String) {
        objectWillChange.send()
        transcript += text
        trimTranscriptIfNeeded()
        persistState()
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        transcript = defaults.string(forKey: transcriptStorageKey) ?? ""
        commandHistory = defaults.stringArray(forKey: historyStorageKey) ?? []
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(transcript, forKey: transcriptStorageKey)
        defaults.set(commandHistory, forKey: historyStorageKey)
    }

    private func trimTranscriptIfNeeded() {
        guard transcript.count > Self.maxTranscriptCharacters else { return }
        transcript = String(transcript.suffix(Self.maxTranscriptCharacters))
    }

    private var transcriptStorageKey: String {
        Self.transcriptPrefix + target.persistenceKey
    }

    private var historyStorageKey: String {
        Self.historyPrefix + target.persistenceKey
    }

    private static func findContainerPath() -> String? {
        let paths = [
            "/usr/local/bin/container",
            "/opt/homebrew/bin/container",
            "/usr/bin/container",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/container").path,
        ]

        for path in paths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["container"]
        process.standardOutput = pipe
        process.standardError = pipe

        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == false) ? path : nil
    }
}
