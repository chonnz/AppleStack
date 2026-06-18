import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Activity Monitor"
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"
    case machines = "Machines"
    case registry = "Registry"
    case builder = "Builder"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .containers: "cube.box.fill"
        case .images: "square.3.layers.3d.down.right"
        case .volumes: "externaldrive"
        case .networks: "network"
        case .machines: "desktopcomputer"
        case .registry: "person.crop.circle.badge.key"
        case .builder: "hammer"
        case .system: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection? = .containers
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var containerViewModel = ContainerListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var imageViewModel = ImageListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var systemViewModel = SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var selectedContainer: Container?
    @State private var selectedImage: Image?
    @State private var selectedVolume: String?
    @State private var selectedNetwork: Network?
    @State private var selectedMachine: Machine?

    private var showsCollapsedSidebarToggle: Bool {
        switch columnVisibility {
        case .doubleColumn, .detailOnly:
            true
        default:
            false
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSection: Binding(
                get: { selectedSection ?? .containers },
                set: { selectedSection = $0 }
            ))
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            Group {
                switch selectedSection {
                case .dashboard:
                    MonitorView()
                case .containers:
                    ContainerListView(
                        viewModel: containerViewModel,
                        selectedContainer: $selectedContainer,
                        showsSidebarToggle: showsCollapsedSidebarToggle,
                        onToggleSidebar: showSidebar
                    )
                case .images:
                    ImageListView(
                        viewModel: imageViewModel,
                        selectedImage: $selectedImage,
                        showsSidebarToggle: showsCollapsedSidebarToggle,
                        onToggleSidebar: showSidebar
                    )
                case .volumes:
                    VolumeListView(
                        selectedVolume: $selectedVolume,
                        showsSidebarToggle: showsCollapsedSidebarToggle,
                        onToggleSidebar: showSidebar
                    )
                case .networks:
                    NetworkListView(
                        selectedNetwork: $selectedNetwork,
                        showsSidebarToggle: showsCollapsedSidebarToggle,
                        onToggleSidebar: showSidebar
                    )
                case .machines:
                    MachineListView(
                        showsSidebarToggle: showsCollapsedSidebarToggle,
                        onToggleSidebar: showSidebar,
                        selectedMachine: $selectedMachine
                    )
                case .registry:
                    RegistryView()
                case .builder:
                    BuilderView()
                case .system:
                    SystemStatusView(viewModel: systemViewModel)
                case .none:
                    Text("Select an item")
                        .foregroundStyle(.secondary)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .navigationSplitViewColumnWidth(
                min: selectedSection == .containers ? 340 : 280,
                ideal: selectedSection == .containers ? 410 : 320,
                max: selectedSection == .containers ? 520 : 400
            )
        } detail: {
            DetailPanel(
                section: selectedSection ?? .containers,
                selectedContainer: selectedContainer,
                selectedImage: selectedImage,
                selectedVolume: selectedVolume,
                selectedNetwork: selectedNetwork,
                selectedMachine: selectedMachine
            )
            .ignoresSafeArea(.container, edges: .top)
        }
        .frame(minWidth: 1000, minHeight: 600)
    }

    private func showSidebar() {
        columnVisibility = .all
    }
}

private struct DetailPanel: View {
    let section: AppSection
    let selectedContainer: Container?
    let selectedImage: Image?
    let selectedVolume: String?
    let selectedNetwork: Network?
    let selectedMachine: Machine?

    @State private var selectedDetailTab = "Info"

    private var tabTitles: [String] {
        switch section {
        case .containers:
            ["Info", "Runtime", "Network", "Logs", "Terminal", "Stats", "Inspect"]
        case .machines:
            ["Info", "Resources", "Terminal", "Inspect"]
        case .images:
            ["Info", "Config", "History", "Inspect"]
        case .volumes:
            ["Info", "Labels", "Options", "Inspect"]
        case .networks:
            ["Info", "Labels", "Options", "Inspect"]
        default:
            ["Info"]
        }
    }

    private var detailKey: String? {
        switch section {
        case .containers:
            guard let selectedContainer else { return nil }
            return "containers.\(selectedContainer.id)"
        case .images:
            guard let selectedImage else { return nil }
            return "images.\(selectedImage.id)"
        case .volumes:
            guard let selectedVolume else { return nil }
            return "volumes.\(selectedVolume)"
        case .networks:
            guard let selectedNetwork else { return nil }
            return "networks.\(selectedNetwork.id)"
        case .machines:
            guard let selectedMachine else { return nil }
            return "machines.\(selectedMachine.id)"
        default:
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                tabSelectorView
                    .layoutPriority(1)

                Spacer()

                trailingControlsView
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(minHeight: 60)
            .background(AppTheme.paneBackground)
            .overlay(alignment: .bottom) {
                Divider()
            }

            if let container = selectedContainer, section == .containers {
                ContainerDetailView(container: container, selectedTab: selectedDetailTab)
            } else if let image = selectedImage, section == .images {
                ImageDetailView(image: image, selectedTab: selectedDetailTab)
            } else if let volume = selectedVolume, section == .volumes {
                VolumeDetailView(volumeName: volume, selectedTab: selectedDetailTab)
            } else if let network = selectedNetwork, section == .networks {
                NetworkDetailView(network: network, selectedTab: selectedDetailTab)
            } else if let machine = selectedMachine, section == .machines {
                MachineDetailView(machine: machine, selectedTab: selectedDetailTab)
            } else {
                VStack {
                    Spacer()
                    Text("No Selection")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.gray.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.paneBackground)
            }
        }
        .onAppear {
            restoreSelectedTab()
        }
        .onChange(of: detailKey) { _, _ in
            restoreSelectedTab()
        }
        .onChange(of: section) { _, _ in
            restoreSelectedTab()
        }
        .onChange(of: selectedDetailTab) { _, newValue in
            guard tabTitles.contains(newValue), let detailKey else { return }
            DetailStateStore.setSelectedTab(newValue, for: detailKey)
        }
    }

    private func restoreSelectedTab() {
        guard let detailKey else {
            selectedDetailTab = tabTitles.first ?? "Info"
            return
        }

        let savedTab = DetailStateStore.selectedTab(for: detailKey)
        if let savedTab, tabTitles.contains(savedTab) {
            selectedDetailTab = savedTab
        } else {
            selectedDetailTab = tabTitles.first ?? "Info"
        }
    }

    @ViewBuilder
    private var tabSelectorView: some View {
        ViewThatFits(in: .horizontal) {
            wideTabSelector
            compactTabSelector
        }
    }

    private var wideTabSelector: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabTitles.enumerated()), id: \.offset) { _, title in
                Button {
                    selectedDetailTab = title
                } label: {
                    DetailTab(title: title, isSelected: selectedDetailTab == title)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.chromeBackground)
        .clipShape(Capsule())
    }

    private var compactTabSelector: some View {
        Menu {
            ForEach(tabTitles, id: \.self) { title in
                Button {
                    selectedDetailTab = title
                } label: {
                    if title == selectedDetailTab {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedDetailTab)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                SwiftUI.Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.chromeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(AppTheme.subtleBorder, lineWidth: 0.8)
            )
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var trailingControlsView: some View {
        ViewThatFits(in: .horizontal) {
            fullTrailingControls
            compactTrailingControls
            minimalTrailingControls
        }
    }

    private var fullTrailingControls: some View {
        HStack(spacing: 10) {
            detailBadge(text: "Personal use only", horizontalPadding: 12)
            externalButton(padded: true)
        }
        .fixedSize()
    }

    private var compactTrailingControls: some View {
        HStack(spacing: 8) {
            detailBadge(text: "Personal", horizontalPadding: 10)
            externalButton(padded: false)
        }
        .fixedSize()
    }

    private var minimalTrailingControls: some View {
        externalButton(padded: false)
            .fixedSize()
    }

    private func detailBadge(text: String, horizontalPadding: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 7)
            .background(AppTheme.badgeBackground)
            .foregroundStyle(AppTheme.badgeForeground)
            .clipShape(Capsule())
    }

    private func externalButton(padded: Bool) -> some View {
        Button(action: {}) {
            SwiftUI.Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(padded ? 7 : 6)
                .background(AppTheme.detailTabBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppTheme.subtleBorder, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct DetailTab: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.detailTabSelectedBackground : Color.clear)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 1.5, y: 1)
    }
}

private struct ImageDetailView: View {
    let image: Image
    let selectedTab: String

    @State private var details: ImageInspectionDetails?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var rawInspectOutput: String?

    var body: some View {
        Group {
            if isLoading && details == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case "Config":
                            imageConfigContent(details)
                        case "History":
                            imageHistoryContent(details)
                        case "Inspect":
                            imageInspectContent
                        default:
                            imageInfoContent(details)
                        }
                    }
                    .padding(16)
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
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
        .background(AppTheme.paneBackground)
        .task(id: image.reference) {
            await loadDetails()
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            let output = try await CLIBackend().inspectImages(references: [image.reference])
            rawInspectOutput = output
            details = try ImageInspectionDetails.parse(from: output, fallback: image)
        } catch {
            details = ImageInspectionDetails.fallback(from: image)
            rawInspectOutput = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func exportImage() {
        let panel = NSSavePanel()
        let exportTag = image.tag.isEmpty ? "image" : image.tag
        panel.nameFieldStringValue = "\(image.repository.replacingOccurrences(of: "/", with: "_"))-\(exportTag).tar"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    _ = try await CLIBackend().saveImages(
                        references: [image.reference],
                        outputPath: url.path,
                        platform: nil
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func imageInfoContent(_ details: ImageInspectionDetails) -> some View {
        ImageDetailSection(title: "Overview") {
            ImageDetailCard {
                ImageDetailRows(
                    rows: [
                        .init(label: "Reference", value: details.reference),
                        .init(label: "ID", value: details.id, usesMonospacedFont: true),
                        .init(label: "Digest", value: details.digest, usesMonospacedFont: true),
                        .init(label: "Created", value: details.createdDisplay),
                        .init(label: "Size", value: details.sizeDisplay),
                        .init(label: "Platform", value: details.platformDisplay),
                        .init(label: "Media Type", value: details.mediaType),
                        .init(label: "Variant Digest", value: details.variantDigest, usesMonospacedFont: true),
                    ].filter(\.hasContent)
                )
            }
        }

        ImageDetailSection(title: "Actions") {
            Button(action: exportImage) {
                HStack(spacing: 12) {
                    SwiftUI.Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.chromeBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Save this image as an OCI-compatible archive")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    SwiftUI.Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func imageConfigContent(_ details: ImageInspectionDetails) -> some View {
        if !details.configRows.isEmpty {
            ImageDetailSection(title: "Config") {
                ImageDetailCard {
                    ImageDetailRows(rows: details.configRows)
                }
            }
        }

        if !details.environment.isEmpty {
            ImageDetailSection(title: "Environment") {
                ImageDetailCard {
                    ImageKeyValueTable(items: details.environment)
                }
            }
        }

        if !details.labels.isEmpty {
            ImageDetailSection(title: "Labels") {
                ImageDetailCard {
                    ImageKeyValueTable(items: details.labels)
                }
            }
        }

        if !details.exposedPorts.isEmpty {
            ImageDetailSection(title: "Exposed Ports") {
                ImageDetailCard {
                    ImageTagFlow(items: details.exposedPorts)
                }
            }
        }

        if !details.volumes.isEmpty {
            ImageDetailSection(title: "Volumes") {
                ImageDetailCard {
                    ImageTagFlow(items: details.volumes)
                }
            }
        }
    }

    @ViewBuilder
    private func imageHistoryContent(_ details: ImageInspectionDetails) -> some View {
        if !details.layers.isEmpty {
            ImageDetailSection(title: "Layers") {
                ImageDetailCard {
                    VStack(spacing: 0) {
                        ForEach(Array(details.layers.enumerated()), id: \.offset) { index, layer in
                            ImageDetailRow(
                                row: .init(
                                    label: "Layer \(index + 1)",
                                    value: layer,
                                    usesMonospacedFont: true
                                )
                            )
                        }
                    }
                }
            }
        }

        if !details.history.isEmpty {
            ImageDetailSection(title: "History") {
                ImageDetailCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(details.history.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.createdDisplay)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let comment = item.comment, !comment.isEmpty {
                                        Text(comment)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(item.command)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 10)

                            if index < details.history.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var imageInspectContent: some View {
        ImageDetailSection(title: "Inspect") {
            ImageDetailCard {
                Text(rawInspectOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? rawInspectOutput! : "No inspect output available")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ImageInspectionDetails {
    struct KeyValueItem {
        let key: String
        let value: String
    }

    struct HistoryItem {
        let createdDisplay: String
        let command: String
        let comment: String?
    }

    let id: String
    let reference: String
    let digest: String
    let variantDigest: String
    let createdDisplay: String
    let sizeDisplay: String
    let platformDisplay: String
    let mediaType: String
    let configRows: [ImageDetailDataRow]
    let environment: [KeyValueItem]
    let labels: [KeyValueItem]
    let exposedPorts: [String]
    let volumes: [String]
    let layers: [String]
    let history: [HistoryItem]

    static func fallback(from image: Image) -> ImageInspectionDetails {
        ImageInspectionDetails(
            id: image.id,
            reference: image.reference,
            digest: "",
            variantDigest: "",
            createdDisplay: image.created,
            sizeDisplay: image.sizeFormatted,
            platformDisplay: "",
            mediaType: "",
            configRows: [
                .init(label: "Repository", value: image.repository),
                .init(label: "Tag", value: image.tag),
            ].filter(\.hasContent),
            environment: [],
            labels: [],
            exposedPorts: [],
            volumes: [],
            layers: [],
            history: []
        )
    }

    static func parse(from output: String, fallback image: Image) throws -> ImageInspectionDetails {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let root = array.first
        else {
            throw CommandError.invalidOutput
        }

        let configuration = root["configuration"] as? [String: Any]
        let descriptor = configuration?["descriptor"] as? [String: Any]
        let variants = root["variants"] as? [[String: Any]] ?? []
        let primaryVariant = variants.first
        let variantConfig = primaryVariant?["config"] as? [String: Any]
        let imageConfig = variantConfig?["config"] as? [String: Any]
        let platform = primaryVariant?["platform"] as? [String: Any]
        let rootfs = variantConfig?["rootfs"] as? [String: Any]
        let historyItems = variantConfig?["history"] as? [[String: Any]] ?? []
        let labels = imageConfig?["Labels"] as? [String: Any] ?? [:]
        let exposedPorts = imageConfig?["ExposedPorts"] as? [String: Any] ?? [:]
        let volumes = imageConfig?["Volumes"] as? [String: Any] ?? [:]

        let digest = descriptor?["digest"] as? String ?? ""
        let variantDigest = primaryVariant?["digest"] as? String ?? ""
        let createdDisplay = formattedTimestamp(
            configuration?["creationDate"] as? String
                ?? primaryVariant?["created"] as? String
                ?? image.created
        )
        let sizeDisplay = formattedSize(
            primaryVariant?["size"] ?? descriptor?["size"]
        ) ?? image.sizeFormatted

        let os = platform?["os"] as? String
            ?? variantConfig?["os"] as? String
            ?? ""
        let architecture = platform?["architecture"] as? String
            ?? variantConfig?["architecture"] as? String
            ?? ""
        let variantName = platform?["variant"] as? String
            ?? variantConfig?["variant"] as? String
            ?? ""
        let platformDisplay = [os, architecture, variantName]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        let command = joinedCommand(imageConfig?["Cmd"])
        let entrypoint = joinedCommand(imageConfig?["Entrypoint"])
        let workdir = imageConfig?["WorkingDir"] as? String ?? ""
        let user = imageConfig?["User"] as? String ?? ""
        let stopSignal = imageConfig?["StopSignal"] as? String ?? ""

        let configRows = [
            ImageDetailDataRow(label: "Repository", value: image.repository),
            ImageDetailDataRow(label: "Tag", value: image.tag),
            ImageDetailDataRow(label: "Command", value: command),
            ImageDetailDataRow(label: "Entrypoint", value: entrypoint),
            ImageDetailDataRow(label: "Working Directory", value: workdir),
            ImageDetailDataRow(label: "User", value: user),
            ImageDetailDataRow(label: "Stop Signal", value: stopSignal),
        ].filter(\.hasContent)

        let environment = parseEnvironment(imageConfig?["Env"])
        let labelItems = labels.keys.sorted().map {
            KeyValueItem(key: $0, value: "\(labels[$0] ?? "")")
        }
        let exposedPortItems = exposedPorts.keys.sorted()
        let volumeItems = volumes.keys.sorted()
        let layerItems = (rootfs?["diff_ids"] as? [String] ?? []).map {
            $0.replacingOccurrences(of: "sha256:", with: "")
        }
        let history = historyItems.map { item in
            HistoryItem(
                createdDisplay: formattedTimestamp(item["created"] as? String ?? ""),
                command: item["created_by"] as? String ?? "",
                comment: item["comment"] as? String
            )
        }

        return ImageInspectionDetails(
            id: root["id"] as? String ?? image.id,
            reference: configuration?["name"] as? String ?? image.reference,
            digest: digest,
            variantDigest: variantDigest,
            createdDisplay: createdDisplay,
            sizeDisplay: sizeDisplay,
            platformDisplay: platformDisplay,
            mediaType: descriptor?["mediaType"] as? String ?? "",
            configRows: configRows,
            environment: environment,
            labels: labelItems,
            exposedPorts: exposedPortItems,
            volumes: volumeItems,
            layers: layerItems,
            history: history
        )
    }

    private static func parseEnvironment(_ rawValue: Any?) -> [KeyValueItem] {
        guard let values = rawValue as? [String] else { return [] }

        return values.map { entry in
            let parts = entry.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return KeyValueItem(key: parts[0], value: parts[1])
            }
            return KeyValueItem(key: entry, value: "")
        }
    }

    private static func joinedCommand(_ rawValue: Any?) -> String {
        if let values = rawValue as? [String], !values.isEmpty {
            return values.joined(separator: " ")
        }
        return ""
    }

    private static func formattedSize(_ rawValue: Any?) -> String? {
        let byteCount: Int64?

        if let value = rawValue as? Int64 {
            byteCount = value
        } else if let value = rawValue as? Int {
            byteCount = Int64(value)
        } else if let value = rawValue as? Double {
            byteCount = Int64(value)
        } else {
            byteCount = nil
        }

        guard let byteCount else { return nil }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
    }

    private static func formattedTimestamp(_ rawValue: String) -> String {
        guard !rawValue.isEmpty else { return "" }
        guard let date = parseISO8601(rawValue) else { return rawValue }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .full
        let relative = relativeFormatter.localizedString(for: date, relativeTo: .now)

        let absolute = date.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )

        return "\(relative) (\(absolute))"
    }

    private static func parseISO8601(_ rawValue: String) -> Date? {
        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }
}

private struct ImageDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            content
        }
    }
}

private struct ImageDetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ImageDetailDataRow {
    let label: String
    let value: String
    var usesMonospacedFont: Bool = false

    var hasContent: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ImageDetailRows: View {
    let rows: [ImageDetailDataRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ImageDetailRow(row: row)
                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct ImageDetailRow: View {
    let row: ImageDetailDataRow

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(row.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 140, alignment: .leading)

            Spacer(minLength: 0)

            Group {
                if row.usesMonospacedFont {
                    Text(row.value)
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    Text(row.value)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }
}

private struct ImageKeyValueTable: View {
    let items: [ImageInspectionDetails.KeyValueItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Value")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 16) {
                    Text(item.key)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 170, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(item.value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)

                if index < items.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct ImageTagFlow: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.chromeBackground)
                    .clipShape(Capsule())
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    ContentView()
}
