import SwiftUI

struct ContainerDetailView: View {
    let container: Container
    @State private var selectedTab = 0
    @State private var logViewModel: LogStreamViewModel
    @State private var terminalInput = ""
    @State private var terminalOutput = ""
    @State private var isExecuting = false

    private let tabs = ["Info", "Logs", "Terminal", "Stats"]

    init(container: Container) {
        self.container = container
        self._logViewModel = State(initialValue: LogStreamViewModel(
            service: CLIBackend(),
            containerId: container.id
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        selectedTab = index
                        if index == 1 {
                            Task { @MainActor in
                                await logViewModel.loadLogs()
                            }
                        }
                    } label: {
                        Text(tab)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedTab == index ? .black : .secondary)
                            .background(selectedTab == index ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white)

            Divider()

            // Tab content
            switch selectedTab {
            case 0:
                infoView
            case 1:
                logsView
            case 2:
                terminalView
            case 3:
                statsView
            default:
                infoView
            }
        }
        .background(.white)
    }

    // MARK: - Info Tab

    private var infoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoSection {
                    InfoRow(label: "Name", value: container.name)
                    InfoRow(label: "ID", value: container.id)
                    InfoRow(label: "Image", value: container.image)
                    InfoRow(label: "Status", value: container.state.rawValue.capitalized)
                    InfoRow(label: "Created", value: container.created)
                }

                if !container.ports.isEmpty {
                    InfoSection(title: "Ports") {
                        InfoRow(label: "Mapping", value: container.ports)
                    }
                }

                InfoSection(title: "Resources") {
                    InfoRow(label: "CPUs", value: "\(container.cpus)")
                    InfoRow(label: "Memory", value: container.memory)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Logs Tab

    private var logsView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    Task { @MainActor in
                        await logViewModel.loadLogs()
                    }
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(logViewModel.isLoading)

                Button {
                    if logViewModel.isStreaming {
                        logViewModel.stopStreaming()
                    } else {
                        logViewModel.startStreaming()
                    }
                } label: {
                    SwiftUI.Image(systemName: logViewModel.isStreaming ? "stop.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(logViewModel.isStreaming ? .red : .green)
                }
                .buttonStyle(.plain)

                Toggle("Auto-scroll", isOn: $logViewModel.autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()

                Button {
                    logViewModel.clearLogs()
                } label: {
                    SwiftUI.Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button {
                    copyLogsToClipboard()
                } label: {
                    SwiftUI.Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Log content
            if logViewModel.isLoading {
                ProgressView("Loading logs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = logViewModel.errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { @MainActor in
                            await logViewModel.loadLogs()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if logViewModel.logs.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No logs")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logViewModel.logs) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.formattedTime)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(entry.content)
                                        .font(.system(size: 12, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: logViewModel.logs.count) { _, _ in
                        if logViewModel.autoScroll, let lastLog = logViewModel.logs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Terminal Tab

    private var terminalView: some View {
        VStack(spacing: 0) {
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Text(terminalOutput.isEmpty ? "Ready. Type a command and press Enter." : terminalOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("output")
                }
                .onChange(of: terminalOutput) { _, _ in
                    withAnimation {
                        proxy.scrollTo("output", anchor: .bottom)
                    }
                }
            }

            Divider()

            // Command input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("Enter command...", text: $terminalInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        executeCommand()
                    }

                Button {
                    executeCommand()
                } label: {
                    SwiftUI.Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(terminalInput.isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(terminalInput.isEmpty || isExecuting)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Stats Tab

    private var statsView: some View {
        StatsView(containerId: container.id)
    }

    // MARK: - Actions

    private func executeCommand() {
        guard !terminalInput.isEmpty else { return }
        let cmd = terminalInput
        terminalInput = ""
        isExecuting = true

        Task {
            do {
                let output = try await CLIBackend().execCommand(
                    containerId: container.id,
                    command: ["exec", container.id] + cmd.split(separator: " ").map(String.init)
                )
                terminalOutput += "$ \(cmd)\n\(output)\n"
            } catch {
                terminalOutput += "$ \(cmd)\nError: \(error.localizedDescription)\n"
            }
            isExecuting = false
        }
    }

    private func copyLogsToClipboard() {
        let logs = logViewModel.exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
    }
}

// MARK: - Stats View

@MainActor
private struct StatsView: View {
    let containerId: String
    @State private var stats: ContainerStats?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cpuHistory: [ResourceDataPoint] = []
    @State private var memoryHistory: [ResourceDataPoint] = []
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    Task {
                        await loadStats()
                    }
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Toggle("Auto-refresh", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if isLoading {
                ProgressView("Loading stats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadStats()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let stats {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Charts
                        MonitorDashboardView(
                            cpuHistory: cpuHistory,
                            memoryHistory: memoryHistory,
                            currentCPU: stats.cpuFormatted,
                            currentMemory: stats.memoryFormatted
                        )

                        // Details
                        InfoSection(title: "Network") {
                            InfoRow(label: "I/O", value: stats.networkIO)
                        }

                        InfoSection(title: "Disk") {
                            InfoRow(label: "I/O", value: stats.blockIO)
                        }

                        InfoSection(title: "Processes") {
                            InfoRow(label: "PIDs", value: "\(stats.pids)")
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No stats available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task {
            await loadStats()
        }
    }

    private func loadStats() async {
        isLoading = true
        errorMessage = nil
        do {
            let newStats = try await CLIBackend().stats(containerId: containerId)
            stats = newStats

            // 添加历史数据点
            let now = Date()
            let cpuValue = newStats.cpuPercent
            let memoryValue = newStats.memoryPercent

            cpuHistory.append(ResourceDataPoint(timestamp: now, value: cpuValue))
            memoryHistory.append(ResourceDataPoint(timestamp: now, value: memoryValue))

            // 保留最近60个数据点（约1分钟）
            if cpuHistory.count > 60 {
                cpuHistory.removeFirst()
            }
            if memoryHistory.count > 60 {
                memoryHistory.removeFirst()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Helper Views

private struct InfoSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

#Preview {
    ContainerDetailView(container: Container(
        id: "abc123",
        name: "my-app",
        image: "nginx:latest",
        status: .running,
        state: .running,
        created: "2 hours ago",
        ports: "8080:80",
        cpus: 2,
        memory: "512m"
    ))
}
