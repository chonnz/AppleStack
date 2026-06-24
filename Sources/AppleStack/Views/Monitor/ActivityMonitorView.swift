import SwiftUI

private enum ActivityMonitorSelection: Equatable {
    case container(id: String)
    case machine(id: String)

    var historyID: String {
        switch self {
        case .container(let id):
            return "container:\(id)"
        case .machine(let id):
            return "machine:\(id)"
        }
    }
}

private enum ActivityRefreshFrequency: String, CaseIterable {
    case oneSecond = "1 second"
    case twoSeconds = "2 seconds"
    case fiveSeconds = "5 seconds"

    var interval: TimeInterval {
        switch self {
        case .oneSecond: 1.0
        case .twoSeconds: 2.0
        case .fiveSeconds: 5.0
        }
    }
}

struct ActivityMonitorView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var containers: [Container] = []
    @State private var machines: [Machine] = []
    @State private var stats: [String: ContainerStats] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedResource: ActivityMonitorSelection?

    // MARK: - Timers for periodic refresh

    @State private var cpuHistory: [ResourceDataPoint] = []
    @State private var memoryHistory: [ResourceDataPoint] = []
    @State private var networkHistory: [ResourceDataPoint] = []
    @State private var diskHistory: [ResourceDataPoint] = []
    @State private var resourceCPUHistory: [String: [ResourceDataPoint]] = [:]
    @State private var resourceMemoryHistory: [String: [ResourceDataPoint]] = [:]
    @State private var resourceNetworkHistory: [String: [ResourceDataPoint]] = [:]
    @State private var resourceDiskHistory: [String: [ResourceDataPoint]] = [:]

    @State private var previousStats: [String: ContainerStats] = [:]
    @State private var previousTimestamp: Date?
    @State private var networkRates: [String: Double] = [:]
    @State private var diskRates: [String: Double] = [:]
    @State private var refreshTask: Task<Void, Never>?
    @State private var lastResourceListRefresh: Date?
    @State private var refreshFrequency: ActivityRefreshFrequency = .oneSecond
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let resourceListRefreshInterval: TimeInterval = 5.0

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private var totalCPU: Double {
        stats.values.reduce(0) { $0 + $1.cpuPercent }
    }

    private var runningContainers: [Container] {
        containers.filter(isRunningContainer)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: language.localized("Activity Monitor"), subtitle: language.localized("Live resource usage")) {
                HeaderMenuButton(systemName: "clock.arrow.circlepath", helpText: language.localized("Update Frequency")) {
                    ForEach(ActivityRefreshFrequency.allCases, id: \.rawValue) { frequency in
                        Button {
                            refreshFrequency = frequency
                        } label: {
                            if refreshFrequency == frequency {
                                Label(language.localized(frequency.rawValue), systemImage: "checkmark")
                            } else {
                                Text(language.localized(frequency.rawValue))
                            }
                        }
                    }
                }

                HeaderCircleButton(
                    systemName: isLoading ? "hourglass" : "arrow.clockwise",
                    action: { Task { await load() } },
                    helpText: language.localized("Refresh")
                )
                .disabled(isLoading)
            }

            if isLoading && containers.isEmpty && machines.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorStateView(message: errorMessage, retryAction: { Task { await load() } })
            } else {
                VStack(spacing: 0) {
                    tableHeader
                    resourceTable
                    Divider()
                    summaryCards
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await load()
            startPeriodicRefresh()
        }
        .onDisappear { stopPeriodicRefresh() }
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshFrequency.interval))
                guard !Task.isCancelled else { break }
                await refreshStats()
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refreshStats() async {
        await refreshResourceList(force: false)
        appendMachineHistory()
        let newStats = await fetchStats(for: runningContainers)
        appendHistorySample(newStats)
    }

    private func refreshResourceList(force: Bool) async {
        let now = Date()
        if !force,
           let lastResourceListRefresh,
           now.timeIntervalSince(lastResourceListRefresh) < resourceListRefreshInterval {
            return
        }

        do {
            // stats 每秒刷新，但容器/虚拟机列表变化频率低；列表降频可避免页面持续堆 CLI 进程。
            async let containersTask = cliBackend.listContainers(all: true)
            async let machinesTask = cliBackend.listMachines()
            containers = try await containersTask
            machines = try await machinesTask
            lastResourceListRefresh = now
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        clearMissingSelection()
    }

    // MARK: - Initial Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        await refreshResourceList(force: true)
        appendMachineHistory()
        await loadStats(for: runningContainers)
        isLoading = false
    }

    private func loadStats(for containers: [Container]) async {
        let loadedStats = await fetchStats(for: containers)
        appendHistorySample(loadedStats)
    }

    private func isRunningContainer(_ container: Container) -> Bool {
        container.status == .running || container.state == .running
    }

    private func fetchStats(for containers: [Container]) async -> [String: ContainerStats] {
        await withTaskGroup(of: (String, ContainerStats)?.self) { group in
            for container in containers {
                group.addTask {
                    if let value = try? await cliBackend.stats(containerId: container.id) {
                        return (container.id, value)
                    }
                    return nil
                }
            }

            var loadedStats: [String: ContainerStats] = [:]
            for await result in group {
                if let result {
                    loadedStats[result.0] = result.1
                }
            }
            return loadedStats
        }
    }

    private func appendHistorySample(_ newStats: [String: ContainerStats]) {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(previousTimestamp ?? now), 0)
        previousTimestamp = now

        let previousNetworkRx = previousStats.values.reduce(0) { $0 + ($1.networkRx.doubleFromBytes ?? 0) }
        let previousBlockWrite = previousStats.values.reduce(0) { $0 + ($1.blockWrite.doubleFromBytes ?? 0) }
        let networkRx = newStats.values.reduce(0) { $0 + ($1.networkRx.doubleFromBytes ?? 0) }
        let blockWrite = newStats.values.reduce(0) { $0 + ($1.blockWrite.doubleFromBytes ?? 0) }

        let cpuSum = newStats.values.reduce(0) { $0 + $1.cpuPercent }
        let memSum = newStats.values.reduce(0) { $0 + ($1.memoryUsage.doubleFromBytes ?? 0) }

        cpuHistory.append(ResourceDataPoint(timestamp: now, value: cpuSum))
        memoryHistory.append(ResourceDataPoint(timestamp: now, value: memSum))

        if elapsed > 0 {
            networkRates = rateMap(newStats: newStats, elapsed: elapsed, value: \.networkRx)
            diskRates = rateMap(newStats: newStats, elapsed: elapsed, value: \.blockWrite)
            networkHistory.append(ResourceDataPoint(timestamp: now, value: max(0, networkRx - previousNetworkRx) / elapsed))
            diskHistory.append(ResourceDataPoint(timestamp: now, value: max(0, blockWrite - previousBlockWrite) / elapsed))
        } else {
            networkRates = [:]
            diskRates = [:]
            networkHistory.append(ResourceDataPoint(timestamp: now, value: 0))
            diskHistory.append(ResourceDataPoint(timestamp: now, value: 0))
        }

        appendContainerHistory(newStats, timestamp: now)
        trimHistory()
        stats = newStats
        previousStats = newStats
    }

    private func appendContainerHistory(_ newStats: [String: ContainerStats], timestamp: Date) {
        for (id, value) in newStats {
            appendResourceHistory(&resourceCPUHistory, id: ActivityMonitorSelection.container(id: id).historyID, timestamp: timestamp, value: value.cpuPercent)
            appendResourceHistory(&resourceMemoryHistory, id: ActivityMonitorSelection.container(id: id).historyID, timestamp: timestamp, value: value.memoryUsage.doubleFromBytes ?? 0)
            appendResourceHistory(&resourceNetworkHistory, id: ActivityMonitorSelection.container(id: id).historyID, timestamp: timestamp, value: networkRates[id] ?? 0)
            appendResourceHistory(&resourceDiskHistory, id: ActivityMonitorSelection.container(id: id).historyID, timestamp: timestamp, value: diskRates[id] ?? 0)
        }
    }

    private func appendMachineHistory() {
        let now = Date()
        for machine in machines {
            let id = ActivityMonitorSelection.machine(id: machine.id).historyID
            appendResourceHistory(&resourceCPUHistory, id: id, timestamp: now, value: machine.status == .running ? 0 : 0)
            appendResourceHistory(&resourceMemoryHistory, id: id, timestamp: now, value: machine.memory.doubleFromBytes ?? 0)
            appendResourceHistory(&resourceNetworkHistory, id: id, timestamp: now, value: 0)
            appendResourceHistory(&resourceDiskHistory, id: id, timestamp: now, value: 0)
        }
    }

    private func appendResourceHistory(
        _ store: inout [String: [ResourceDataPoint]],
        id: String,
        timestamp: Date,
        value: Double
    ) {
        store[id, default: []].append(ResourceDataPoint(timestamp: timestamp, value: value))
        if let count = store[id]?.count, count > 60 {
            store[id]?.removeFirst(count - 60)
        }
    }

    private func rateMap(
        newStats: [String: ContainerStats],
        elapsed: TimeInterval,
        value: KeyPath<ContainerStats, String>
    ) -> [String: Double] {
        var rates: [String: Double] = [:]
        for (id, stats) in newStats {
            let current = stats[keyPath: value].doubleFromBytes ?? 0
            let previous = previousStats[id]?[keyPath: value].doubleFromBytes ?? current
            rates[id] = max(0, current - previous) / elapsed
        }
        return rates
    }

    private func trimHistory() {
        if cpuHistory.count > 60 { cpuHistory.removeFirst(cpuHistory.count - 60) }
        if memoryHistory.count > 60 { memoryHistory.removeFirst(memoryHistory.count - 60) }
        if networkHistory.count > 60 { networkHistory.removeFirst(networkHistory.count - 60) }
        if diskHistory.count > 60 { diskHistory.removeFirst(diskHistory.count - 60) }
    }

    private func clearMissingSelection() {
        guard let selectedResource else { return }
        switch selectedResource {
        case .container(let id):
            if !containers.contains(where: { $0.id == id }) {
                self.selectedResource = nil
            }
        case .machine(let id):
            if !machines.contains(where: { $0.id == id }) {
                self.selectedResource = nil
            }
        }
    }

    // MARK: - UI Sections

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text(language.localized("Name"))
                .frame(maxWidth: .infinity, alignment: .leading)
            metricHeader("CPU %", width: 100)
            metricHeader("Memory", width: 140)
            metricHeader("Network", width: 130)
            metricHeader("Disk", width: 130)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func metricHeader(_ title: String, width: CGFloat) -> some View {
        Text(language.localized(title))
            .frame(width: width, alignment: .trailing)
            .overlay(alignment: .leading) { Divider() }
    }

    private var resourceTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                groupRow(title: "Containers", icon: "shippingbox.fill", value: containerSummary, rowIndex: 0)
                ForEach(Array(containers.enumerated()), id: \.element.id) { index, container in
                    containerRow(container, index: index)
                }

                groupRow(title: "Engine", icon: "gearshape.fill", value: "", rowIndex: containers.count + 1)

                groupRow(title: "Machines", icon: "desktopcomputer", value: machineSummary, rowIndex: containers.count + 2)
                ForEach(Array(machines.enumerated()), id: \.element.id) { index, machine in
                    machineRow(machine, index: index)
                }

                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color(nsColor: .controlBackgroundColor).opacity(0.45) : Color.clear)
                        .frame(height: 24)
                }
            }
        }
    }

    private var containerSummary: String {
        "\(runningContainers.count) \(language.localized("running"))"
    }

    private var machineSummary: String {
        "\(machines.filter { $0.status == .running }.count) \(language.localized("running"))"
    }

    private func groupRow(title: String, icon: String, value: String, rowIndex: Int) -> some View {
        activityRow(
            icon: icon,
            iconColor: .primary,
            name: language.localized(title),
            detail: value,
            cpu: groupCPU(for: title),
            memory: groupMemory(for: title),
            network: "0 KB/s",
            disk: "0 KB/s",
            indent: 0,
            rowIndex: rowIndex,
            isGroup: true,
            isSelected: false,
            action: {}
        )
    }

    private func containerRow(_ container: Container, index: Int) -> some View {
        let itemStats = stats[container.id]
        return activityRow(
            icon: "cube.box.fill",
            iconColor: container.statusColor,
            name: container.name,
            detail: container.image,
            cpu: cpuText(itemStats),
            memory: itemStats?.memoryUsage ?? "-",
            network: rateText(networkRates[container.id]),
            disk: rateText(diskRates[container.id]),
            indent: 28,
            rowIndex: index,
            isGroup: false,
            isSelected: selectedResource == .container(id: container.id),
            action: { selectedResource = .container(id: container.id) }
        )
    }

    private func machineRow(_ machine: Machine, index: Int) -> some View {
        activityRow(
            icon: "desktopcomputer",
            iconColor: machine.status == .running ? .green : .secondary,
            name: machine.name,
            detail: machine.image,
            cpu: machine.status == .running ? "0.0" : "-",
            memory: machine.memory,
            network: "0 KB/s",
            disk: "0 KB/s",
            indent: 28,
            rowIndex: index,
            isGroup: false,
            isSelected: selectedResource == .machine(id: machine.id),
            action: { selectedResource = .machine(id: machine.id) }
        )
    }

    private func activityRow(
        icon: String,
        iconColor: Color,
        name: String,
        detail: String,
        cpu: String,
        memory: String,
        network: String,
        disk: String,
        indent: CGFloat,
        rowIndex: Int,
        isGroup: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                SwiftUI.Image(systemName: isGroup ? "chevron.down" : "")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .frame(width: 14)
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: isGroup ? 15 : 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : iconColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: isGroup ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 22 + indent)
            .frame(maxWidth: .infinity, alignment: .leading)

            metricText(cpu, width: 100, isSelected: isSelected)
            metricText(memory, width: 140, isSelected: isSelected)
            metricText(network, width: 130, isSelected: isSelected)
            metricText(disk, width: 130, isSelected: isSelected)
        }
        .frame(height: 24)
        .background(rowBackground(rowIndex: rowIndex, isSelected: isSelected))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private func metricText(_ text: String, width: CGFloat, isSelected: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(width: width, alignment: .trailing)
            .padding(.trailing, 12)
    }

    private func rowBackground(rowIndex: Int, isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.listSelection)
        }
        if rowIndex.isMultiple(of: 2) {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            summaryCard(title: "\(language.localized(summaryTitlePrefix)) CPU:", value: cpuSummaryText, tint: .red, history: displayedCPUHistory)
            summaryCard(title: language.localized("Memory:"), value: memorySummaryText, tint: .blue, history: displayedMemoryHistory)
            summaryCard(title: language.localized("Network:"), value: networkSummaryText, tint: .green, history: displayedNetworkHistory)
            summaryCard(title: language.localized("Disk:"), value: diskSummaryText, tint: .purple, history: displayedDiskHistory)
        }
        .padding(14)
        .frame(height: 136)
    }

    private var summaryTitlePrefix: String {
        selectedResource == nil ? "Total" : "Selected"
    }

    private var displayedCPUHistory: [ResourceDataPoint] {
        displayedHistory(resourceCPUHistory, fallback: cpuHistory)
    }

    private var displayedMemoryHistory: [ResourceDataPoint] {
        displayedHistory(resourceMemoryHistory, fallback: memoryHistory)
    }

    private var displayedNetworkHistory: [ResourceDataPoint] {
        displayedHistory(resourceNetworkHistory, fallback: networkHistory)
    }

    private var displayedDiskHistory: [ResourceDataPoint] {
        displayedHistory(resourceDiskHistory, fallback: diskHistory)
    }

    private func displayedHistory(
        _ store: [String: [ResourceDataPoint]],
        fallback: [ResourceDataPoint]
    ) -> [ResourceDataPoint] {
        guard let selectedResource else { return fallback }
        return store[selectedResource.historyID] ?? []
    }

    private var cpuSummaryText: String {
        switch selectedResource {
        case .container(let id):
            return String(format: "%.1f%%", stats[id]?.cpuPercent ?? 0)
        case .machine:
            return "0.0%"
        case nil:
            return String(format: "%.1f%%", totalCPU)
        }
    }

    private var memorySummaryText: String {
        switch selectedResource {
        case .container(let id):
            return stats[id]?.memoryUsage ?? "-"
        case .machine(let id):
            return machines.first(where: { $0.id == id })?.memory ?? "-"
        case nil:
            return totalMemoryText
        }
    }

    private var networkSummaryText: String {
        switch selectedResource {
        case .container(let id):
            return rateText(networkRates[id])
        case .machine:
            return "0 KB/s"
        case nil:
            return networkRateText
        }
    }

    private var diskSummaryText: String {
        switch selectedResource {
        case .container(let id):
            return rateText(diskRates[id])
        case .machine:
            return "0 KB/s"
        case nil:
            return diskRateText
        }
    }

    private var networkRateText: String {
        let lastSample = networkHistory.last
        return lastSample != nil ? String(format: "%.1f KB/s", lastSample!.value) : "0 KB/s"
    }

    private var diskRateText: String {
        let lastSample = diskHistory.last
        return lastSample != nil ? String(format: "%.1f KB/s", lastSample!.value) : "0 KB/s"
    }

    private func summaryCard(title: String, value: String, tint: Color, history: [ResourceDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            DynamicSparkline(dataPoints: history, tint: tint)
                .frame(height: 28)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var totalMemoryText: String {
        let memoryKB = stats.values.reduce(0) { $0 + ($1.memoryUsage.doubleFromBytes ?? 0) }
        return formatKilobytes(memoryKB)
    }

    private func groupCPU(for title: String) -> String {
        title == "Containers" ? String(format: "%.1f", totalCPU) : "0.0"
    }

    private func groupMemory(for title: String) -> String {
        title == "Containers" ? totalMemoryText : "-"
    }

    private func cpuText(_ stats: ContainerStats?) -> String {
        guard let stats else { return "-" }
        return String(format: "%.1f", stats.cpuPercent)
    }

    private func rateText(_ value: Double?) -> String {
        guard let value else { return "0 KB/s" }
        return String(format: value >= 10 ? "%.0f KB/s" : "%.1f KB/s", value)
    }

    private func formatKilobytes(_ value: Double) -> String {
        if value >= 1024 * 1024 {
            return String(format: "%.1f GB", value / 1024 / 1024)
        }
        if value >= 1024 {
            return String(format: "%.0f MB", value / 1024)
        }
        return String(format: "%.0f KB", value)
    }
}

// MARK: - Dynamic Sparkline

private struct DynamicSparkline: View {
    let dataPoints: [ResourceDataPoint]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard !dataPoints.isEmpty else {
                    // Draw flat line at bottom when no data
                    let half = proxy.size.width / 2
                    path.move(to: CGPoint(x: 0, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: half, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    return
                }

                let values = dataPoints.map(\.value)
                let maxVal = values.max() ?? 1
                let minVal = values.min() ?? 0
                let range = max(maxVal - minVal, 0.01)
                let step = proxy.size.width / CGFloat(max(dataPoints.count - 1, 1))
                let isFlat = abs(maxVal - minVal) < 0.01

                for (index, value) in values.enumerated() {
                    let normalized = isFlat ? 0.5 : (value - minVal) / range
                    let point = CGPoint(
                        x: CGFloat(index) * step,
                        y: proxy.size.height * (1 - normalized)
                    )
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
    }
}

// MARK: - Helpers

extension String {
    var doubleFromBytes: Double? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard let rawNumber = parts.first, let number = Double(rawNumber) else {
            return Double(trimmed)
        }

        let unit = parts.dropFirst().joined(separator: " ").lowercased()
        if unit.hasPrefix("byte") {
            return number / 1024
        }
        if unit == "kb" || unit == "kib" {
            return number
        }
        if unit == "mb" || unit == "mib" {
            return number * 1024
        }
        if unit == "gb" || unit == "gib" {
            return number * 1024 * 1024
        }
        return number
    }
}

#Preview {
    ActivityMonitorView()
}
