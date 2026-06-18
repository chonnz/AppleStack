import SwiftUI

struct ContainerDetailView: View {
    let container: Container
    let selectedTab: String

    @State private var logViewModel: LogStreamViewModel
    @StateObject private var terminalSession: PersistentTerminalSession
    @State private var details: ContainerInspectionDetails?
    @State private var isLoadingInfo = false
    @State private var infoErrorMessage: String?
    @State private var rawInspectOutput: String?

    private let cliBackend = CLIBackend()

    init(container: Container, selectedTab: String = "Info") {
        self.container = container
        self.selectedTab = selectedTab
        self._logViewModel = State(initialValue: LogStreamViewModel(
            service: CLIBackend(),
            containerId: container.id
        ))
        self._terminalSession = StateObject(wrappedValue: PersistentTerminalSession(
            target: .container(id: container.id)
        ))
    }

    var body: some View {
        Group {
            switch selectedTab {
            case "Runtime":
                runtimeView
            case "Network":
                networkView
            case "Logs":
                logsView
            case "Terminal":
                terminalView
            case "Stats":
                statsView
            case "Inspect":
                inspectView
            default:
                infoView
            }
        }
        .background(AppTheme.paneBackground)
        .task(id: container.id) {
            guard container.status == .running else { return }
            await ContainerStatsStore.preloadIfNeeded(containerId: container.id)
        }
        .task(id: selectedTab) {
            if ["Info", "Runtime", "Network", "Inspect"].contains(selectedTab), details == nil {
                await loadDetails()
            } else if selectedTab == "Logs" {
                await logViewModel.loadLogs()
            }
        }
    }

    // MARK: - Info Tab

    private var infoView: some View {
        Group {
            if isLoadingInfo && details == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        InspectorSection(title: "Overview") {
                            InspectorCard {
                                InspectorRows(rows: details.overviewRows)
                            }
                        }

                        if !details.portMappings.isEmpty {
                            InspectorSection(title: "Published Ports") {
                                InspectorCard {
                                    InspectorTagFlow(items: details.portMappings)
                                }
                            }
                        }

                        if !details.environment.isEmpty {
                            InspectorSection(title: "Environment") {
                                InspectorCard {
                                    InspectorKeyValueTable(items: details.environment)
                                }
                            }
                        }

                        if !details.labels.isEmpty {
                            InspectorSection(title: "Labels") {
                                InspectorCard {
                                    InspectorKeyValueTable(items: details.labels)
                                }
                            }
                        }

                        if !details.mounts.isEmpty {
                            InspectorSection(title: "Mounts") {
                                InspectorCard {
                                    InspectorTagFlow(items: details.mounts)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else if let infoErrorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(infoErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadDetails() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                Color.clear
            }
        }
    }

    private var runtimeView: some View {
        Group {
            if isLoadingInfo && details == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !details.runtimeRows.isEmpty {
                            InspectorSection(title: "Runtime") {
                                InspectorCard {
                                    InspectorRows(rows: details.runtimeRows)
                                }
                            }
                        }

                        if !details.environment.isEmpty {
                            InspectorSection(title: "Environment") {
                                InspectorCard {
                                    InspectorKeyValueTable(items: details.environment)
                                }
                            }
                        }

                        if !details.labels.isEmpty {
                            InspectorSection(title: "Labels") {
                                InspectorCard {
                                    InspectorKeyValueTable(items: details.labels)
                                }
                            }
                        }

                        if !details.dnsRows.isEmpty {
                            InspectorSection(title: "DNS") {
                                InspectorCard {
                                    InspectorRows(rows: details.dnsRows)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                Color.clear
            }
        }
    }

    private var networkView: some View {
        Group {
            if isLoadingInfo && details == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !details.networkRows.isEmpty {
                            InspectorSection(title: "Network") {
                                InspectorCard {
                                    InspectorRows(rows: details.networkRows)
                                }
                            }
                        }

                        if !details.portMappings.isEmpty {
                            InspectorSection(title: "Published Ports") {
                                InspectorCard {
                                    InspectorTagFlow(items: details.portMappings)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                Color.clear
            }
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
        NativeTerminalView(
            sessionTitle: "Container Terminal",
            sessionSubtitle: container.name,
            prompt: "\(container.name) %",
            placeholder: "Enter shell command",
            isAvailable: container.status == .running,
            unavailableTitle: "Container is not running",
            unavailableMessage: "Start the container to open a shell session.",
            session: terminalSession
        )
    }

    private var inspectView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Inspect") {
                    InspectorCard {
                        Text(rawInspectOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? rawInspectOutput! : "No inspect output available")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Stats Tab

    private var statsView: some View {
        StatsView(containerId: container.id)
    }

    // MARK: - Actions

    private func loadDetails() async {
        isLoadingInfo = true
        infoErrorMessage = nil

        do {
            let output = try await cliBackend.inspectContainers(ids: [container.id])
            rawInspectOutput = output
            details = try ContainerInspectionDetails.parse(from: output, fallback: container)
        } catch {
            details = ContainerInspectionDetails.fallback(from: container)
            rawInspectOutput = nil
            infoErrorMessage = error.localizedDescription
        }

        isLoadingInfo = false
    }

    private func copyLogsToClipboard() {
        let logs = logViewModel.exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
    }
}

private struct ContainerInspectionDetails {
    let overviewRows: [InspectorDataRow]
    let runtimeRows: [InspectorDataRow]
    let networkRows: [InspectorDataRow]
    let dnsRows: [InspectorDataRow]
    let environment: [InspectorKeyValueItem]
    let labels: [InspectorKeyValueItem]
    let mounts: [String]
    let portMappings: [String]

    static func fallback(from container: Container) -> ContainerInspectionDetails {
        ContainerInspectionDetails(
            overviewRows: [
                .init(label: "Name", value: container.name),
                .init(label: "ID", value: container.id, usesMonospacedFont: true),
                .init(label: "Image", value: container.image),
                .init(label: "State", value: container.state.rawValue.capitalized),
                .init(label: "Created", value: container.created),
            ].filter(\.hasContent),
            runtimeRows: [
                .init(label: "CPUs", value: "\(container.cpus)"),
                .init(label: "Memory", value: container.memory),
            ].filter(\.hasContent),
            networkRows: [],
            dnsRows: [],
            environment: [],
            labels: [],
            mounts: [],
            portMappings: container.ports.isEmpty ? [] : [container.ports]
        )
    }

    static func parse(from output: String, fallback container: Container) throws -> ContainerInspectionDetails {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let root = array.first
        else {
            throw CommandError.invalidOutput
        }

        let configuration = root["configuration"] as? [String: Any]
        let status = root["status"] as? [String: Any]
        let image = configuration?["image"] as? [String: Any]
        let imageDescriptor = image?["descriptor"] as? [String: Any]
        let initProcess = configuration?["initProcess"] as? [String: Any]
        let resources = configuration?["resources"] as? [String: Any]
        let platform = configuration?["platform"] as? [String: Any]
        let dns = configuration?["dns"] as? [String: Any]
        let labels = configuration?["labels"] as? [String: Any] ?? [:]
        let mounts = configuration?["mounts"] as? [[String: Any]] ?? []
        let publishedPorts = configuration?["publishedPorts"] as? [[String: Any]] ?? []
        let networks = status?["networks"] as? [[String: Any]] ?? []

        let platformDisplay = [
            platform?["os"] as? String ?? "",
            platform?["architecture"] as? String ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "/")

        let state = status?["state"] as? String ?? container.state.rawValue
        let startedDate = inspectorFormatTimestamp(status?["startedDate"] as? String ?? "")

        let overviewRows = [
            InspectorDataRow(label: "Name", value: configuration?["id"] as? String ?? container.name),
            InspectorDataRow(label: "ID", value: root["id"] as? String ?? container.id, usesMonospacedFont: true),
            InspectorDataRow(label: "Image", value: image?["reference"] as? String ?? container.image),
            InspectorDataRow(label: "Image Digest", value: imageDescriptor?["digest"] as? String ?? "", usesMonospacedFont: true),
            InspectorDataRow(label: "State", value: state.capitalized),
            InspectorDataRow(label: "Created", value: inspectorFormatTimestamp(configuration?["creationDate"] as? String ?? container.created)),
            InspectorDataRow(label: "Started", value: startedDate),
            InspectorDataRow(label: "Platform", value: platformDisplay),
        ].filter(\.hasContent)

        let runtimeRows = [
            InspectorDataRow(label: "Command", value: inspectorFormatCommand(initProcess?["arguments"])),
            InspectorDataRow(label: "Entrypoint", value: initProcess?["executable"] as? String ?? ""),
            InspectorDataRow(label: "Working Directory", value: initProcess?["workingDirectory"] as? String ?? ""),
            InspectorDataRow(
                label: "User",
                value: userDisplay(from: initProcess?["user"] as? [String: Any]),
                usesMonospacedFont: true
            ),
            InspectorDataRow(label: "Stop Signal", value: configuration?["stopSignal"] as? String ?? ""),
            InspectorDataRow(label: "Runtime", value: configuration?["runtimeHandler"] as? String ?? ""),
            InspectorDataRow(label: "CPUs", value: "\(resources?["cpus"] as? Int ?? container.cpus)"),
            InspectorDataRow(label: "Memory", value: inspectorFormatBytes(resources?["memoryInBytes"]) ?? container.memory),
            InspectorDataRow(label: "Read Only", value: boolDisplay(configuration?["readOnly"] as? Bool)),
            InspectorDataRow(label: "Virtualization", value: boolDisplay(configuration?["virtualization"] as? Bool)),
            InspectorDataRow(label: "Rosetta", value: boolDisplay(configuration?["rosetta"] as? Bool)),
            InspectorDataRow(label: "SSH", value: boolDisplay(configuration?["ssh"] as? Bool)),
        ].filter(\.hasContent)

        let networkRows = networks.flatMap { network in
            [
                InspectorDataRow(label: "Network", value: network["network"] as? String ?? ""),
                InspectorDataRow(label: "Hostname", value: network["hostname"] as? String ?? ""),
                InspectorDataRow(label: "IPv4", value: network["ipv4Address"] as? String ?? ""),
                InspectorDataRow(label: "IPv4 Gateway", value: network["ipv4Gateway"] as? String ?? ""),
                InspectorDataRow(label: "IPv6", value: network["ipv6Address"] as? String ?? ""),
                InspectorDataRow(label: "MAC", value: network["macAddress"] as? String ?? "", usesMonospacedFont: true),
                InspectorDataRow(label: "MTU", value: "\(network["mtu"] as? Int ?? 0)"),
            ].filter(\.hasContent)
        }

        let dnsRows = [
            InspectorDataRow(label: "Nameservers", value: (dns?["nameservers"] as? [String] ?? []).joined(separator: ", "), usesMonospacedFont: true),
            InspectorDataRow(label: "Search Domains", value: (dns?["searchDomains"] as? [String] ?? []).joined(separator: ", ")),
            InspectorDataRow(label: "Options", value: (dns?["options"] as? [String] ?? []).joined(separator: ", ")),
        ].filter(\.hasContent)

        let environment = inspectorParseEnvironment(initProcess?["environment"])
        let labelItems = labels.keys.sorted().map {
            InspectorKeyValueItem(key: $0, value: "\(labels[$0] ?? "")")
        }
        let mountItems = mounts.compactMap { mount in
            let source = mount["source"] as? String ?? ""
            let destination = mount["destination"] as? String ?? mount["target"] as? String ?? ""
            let mode = mount["readOnly"] as? Bool == true ? "ro" : "rw"
            let joined = [source, destination].filter { !$0.isEmpty }.joined(separator: " -> ")
            return joined.isEmpty ? nil : "\(joined) (\(mode))"
        }
        let portMappingItems = publishedPorts.compactMap { port -> String? in
            guard let containerPort = port["containerPort"] as? Int else { return nil }
            let hostAddress = port["hostAddress"] as? String ?? "0.0.0.0"
            let hostPort = port["hostPort"] as? Int ?? 0
            let proto = port["proto"] as? String ?? "tcp"
            return "\(hostAddress):\(hostPort) -> \(containerPort)/\(proto)"
        }

        return ContainerInspectionDetails(
            overviewRows: overviewRows,
            runtimeRows: runtimeRows,
            networkRows: networkRows,
            dnsRows: dnsRows,
            environment: environment,
            labels: labelItems,
            mounts: mountItems,
            portMappings: portMappingItems
        )
    }

    private static func userDisplay(from rawValue: [String: Any]?) -> String {
        let id = rawValue?["id"] as? [String: Any]
        let uid = id?["uid"] as? Int
        let gid = id?["gid"] as? Int

        switch (uid, gid) {
        case let (uid?, gid?):
            return "\(uid):\(gid)"
        case let (uid?, nil):
            return "\(uid)"
        default:
            return ""
        }
    }

    private static func boolDisplay(_ value: Bool?) -> String {
        guard let value else { return "" }
        return value ? "Yes" : "No"
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
    @State private var isAutoRefreshEnabled = true
    @State private var refreshTask: Task<Void, Never>?
    @State private var previousCPUUsageUsec: Int64?
    @State private var previousCPUTimestamp: Date?
    @State private var lastUpdatedAt: Date?

    private let refreshIntervalNanoseconds: UInt64 = 2_000_000_000

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

                Toggle("Auto-refresh", isOn: $isAutoRefreshEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()

                if let lastUpdatedAt {
                    Text("Updated \(lastUpdatedAt, style: .time)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if isLoading && stats == nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        statsLoadingPlaceholder
                    }
                    .padding(16)
                }
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
                        summaryCards(stats: stats)

                        MonitorDashboardView(
                            cpuHistory: cpuHistory,
                            memoryHistory: memoryHistory,
                            currentCPU: stats.cpuFormatted,
                            currentMemory: "\(stats.memoryFormatted)  •  \(stats.memoryUsage) / \(stats.memoryLimit)",
                            cpuSubtitle: "Peak \(cpuPeakDisplay)",
                            memorySubtitle: "Peak \(memoryPeakDisplay)"
                        )

                        InfoSection(title: "Network") {
                            InfoRow(label: "Receive", value: stats.networkRx)
                            InfoRow(label: "Transmit", value: stats.networkTx)
                            InfoRow(label: "Total", value: stats.networkIO)
                        }

                        InfoSection(title: "Disk") {
                            InfoRow(label: "Read", value: stats.blockRead)
                            InfoRow(label: "Write", value: stats.blockWrite)
                            InfoRow(label: "Total", value: stats.blockIO)
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
            restoreCachedSnapshot()
            updateAutoRefreshTask()
            if !ContainerStatsStore.hasFreshSnapshot(for: containerId) {
                await loadStats()
            }
        }
        .onChange(of: isAutoRefreshEnabled) { _, _ in
            updateAutoRefreshTask()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private var statsLoadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            let columns = [
                GridItem(.adaptive(minimum: 160), spacing: 12)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
                        )
                        .frame(height: 112)
                        .redacted(reason: .placeholder)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    placeholderChartCard
                    placeholderChartCard
                }

                VStack(spacing: 16) {
                    placeholderChartCard
                    placeholderChartCard
                }
            }

            HStack(spacing: 16) {
                placeholderInfoSection
                placeholderInfoSection
            }

            placeholderInfoSection
        }
    }

    private var placeholderChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 92, height: 12)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 96)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .redacted(reason: .placeholder)
    }

    private var placeholderInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 72, height: 12)

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 14)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .redacted(reason: .placeholder)
    }

    private var cpuPeakDisplay: String {
        let value = cpuHistory.map(\.value).max() ?? stats?.cpuPercent ?? 0
        return String(format: "%.2f%%", value)
    }

    private var memoryPeakDisplay: String {
        let value = memoryHistory.map(\.value).max() ?? stats?.memoryPercent ?? 0
        return String(format: "%.2f%%", value)
    }

    @ViewBuilder
    private func summaryCards(stats: ContainerStats) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 160), spacing: 12)
        ]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            StatsSummaryCard(
                title: "CPU",
                value: stats.cpuFormatted,
                subtitle: "Peak \(cpuPeakDisplay)",
                tint: .blue,
                systemImage: "cpu"
            )
            StatsSummaryCard(
                title: "Memory",
                value: stats.memoryUsage,
                subtitle: "\(stats.memoryFormatted) of \(stats.memoryLimit)",
                tint: .purple,
                systemImage: "memorychip"
            )
            StatsSummaryCard(
                title: "Network",
                value: stats.networkRx,
                subtitle: "Tx \(stats.networkTx)",
                tint: .green,
                systemImage: "network"
            )
            StatsSummaryCard(
                title: "Disk",
                value: stats.blockRead,
                subtitle: "Write \(stats.blockWrite)",
                tint: .orange,
                systemImage: "internaldrive"
            )
            StatsSummaryCard(
                title: "Processes",
                value: "\(stats.pids)",
                subtitle: "Live process count",
                tint: .secondary,
                systemImage: "list.number"
            )
        }
    }


    private func loadStats(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator || stats == nil {
            isLoading = true
        }
        errorMessage = nil
        do {
            let rawStats = try await CLIBackend().stats(containerId: containerId)
            let now = Date()
            let cpuPercent = rawStats.resolvedCPUPercent(
                previousUsageUsec: previousCPUUsageUsec,
                previousTimestamp: previousCPUTimestamp,
                currentTimestamp: now
            )
            let newStats = rawStats.withCPUPercent(cpuPercent)

            previousCPUUsageUsec = rawStats.cpuUsageUsec
            previousCPUTimestamp = now
            stats = newStats
            lastUpdatedAt = now

            // 添加历史数据点
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

            ContainerStatsStore.store(
                CachedContainerStatsSnapshot(
                    stats: newStats,
                    cpuHistory: cpuHistory,
                    memoryHistory: memoryHistory,
                    previousCPUUsageUsec: previousCPUUsageUsec,
                    previousCPUTimestamp: previousCPUTimestamp,
                    lastUpdatedAt: lastUpdatedAt
                ),
                for: containerId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func updateAutoRefreshTask() {
        refreshTask?.cancel()
        refreshTask = nil

        guard isAutoRefreshEnabled else { return }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                await loadStats(showLoadingIndicator: false)
            }
        }
    }

    private func restoreCachedSnapshot() {
        guard let snapshot = ContainerStatsStore.snapshot(for: containerId) else { return }
        stats = snapshot.stats
        cpuHistory = snapshot.cpuHistory
        memoryHistory = snapshot.memoryHistory
        previousCPUUsageUsec = snapshot.previousCPUUsageUsec
        previousCPUTimestamp = snapshot.previousCPUTimestamp
        lastUpdatedAt = snapshot.lastUpdatedAt
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

private struct StatsSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        SwiftUI.Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CachedContainerStatsSnapshot {
    let stats: ContainerStats
    let cpuHistory: [ResourceDataPoint]
    let memoryHistory: [ResourceDataPoint]
    let previousCPUUsageUsec: Int64?
    let previousCPUTimestamp: Date?
    let lastUpdatedAt: Date?
}

@MainActor
private enum ContainerStatsStore {
    private static var snapshots: [String: CachedContainerStatsSnapshot] = [:]
    private static let freshnessInterval: TimeInterval = 3

    static func snapshot(for containerId: String) -> CachedContainerStatsSnapshot? {
        snapshots[containerId]
    }

    static func store(_ snapshot: CachedContainerStatsSnapshot, for containerId: String) {
        snapshots[containerId] = snapshot
    }

    static func hasFreshSnapshot(for containerId: String) -> Bool {
        guard let snapshot = snapshots[containerId],
              let lastUpdatedAt = snapshot.lastUpdatedAt
        else {
            return false
        }

        return Date().timeIntervalSince(lastUpdatedAt) < freshnessInterval
    }

    static func preloadIfNeeded(containerId: String) async {
        guard !hasFreshSnapshot(for: containerId) else { return }

        do {
            let rawStats = try await CLIBackend().stats(containerId: containerId)
            let now = Date()
            let stats = rawStats.withCPUPercent(rawStats.cpuPercent)
            let cpuHistory = [ResourceDataPoint(timestamp: now, value: stats.cpuPercent)]
            let memoryHistory = [ResourceDataPoint(timestamp: now, value: stats.memoryPercent)]

            store(
                CachedContainerStatsSnapshot(
                    stats: stats,
                    cpuHistory: cpuHistory,
                    memoryHistory: memoryHistory,
                    previousCPUUsageUsec: rawStats.cpuUsageUsec,
                    previousCPUTimestamp: now,
                    lastUpdatedAt: now
                ),
                for: containerId
            )
        } catch {
            // Best-effort warmup; the visible Stats view handles surfaced errors.
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
