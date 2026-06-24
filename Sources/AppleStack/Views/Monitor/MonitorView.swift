import SwiftUI

struct MonitorView: View {
    let showsTopBar: Bool
    let isEmbedded: Bool
    @Environment(\.cliBackend) private var cliBackend
    @State private var systemInfo: SystemInfo?
    @State private var containers: [Container] = []
    @State private var images: [Image] = []
    @State private var volumes: [String] = []
    @State private var networks: [Network] = []
    @State private var machines: [Machine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let embeddedRefreshInterval: TimeInterval = 8.0

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private var isRunning: Bool {
        systemInfo?.isRunning ?? false
    }

    init(showsTopBar: Bool = true, isEmbedded: Bool = false) {
        self.showsTopBar = showsTopBar
        self.isEmbedded = isEmbedded
    }

    var body: some View {
        Group {
            if isEmbedded {
                dashboardContent
            } else {
                ScrollView {
                    dashboardContent
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await loadDashboard()
            guard isEmbedded else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(embeddedRefreshInterval))
                guard !Task.isCancelled else { break }
                await loadDashboard(showLoading: false)
            }
        }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsTopBar {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }

            if isLoading && systemInfo == nil && containers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(language.localized("Retry")) {
                        Task { await loadDashboard() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                statsSection
                activitySection
            }
        }
        .padding(.bottom, showsTopBar ? 20 : 0)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(language.localized(isRunning ? "Running" : "Stopped"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isRunning ? .green : .red)
                }
                Text(language.localized("Dashboard"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }

            Spacer()

            Button {
                Task { await loadDashboard() }
            } label: {
                SwiftUI.Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                StatCard(
                    title: language.localized("Containers"),
                    value: "\(containers.count)",
                    subtitle: "\(containers.filter { $0.state == .running }.count) \(language.localized("running"))",
                    icon: "shippingbox.fill",
                    color: .blue
                )

                StatCard(
                    title: language.localized("Images"),
                    value: "\(images.count)",
                    subtitle: language.localized("local images"),
                    icon: "photo.stack.fill",
                    color: .purple
                )

                StatCard(
                    title: language.localized("Networks"),
                    value: "\(networks.count)",
                    subtitle: language.localized("networks"),
                    icon: "network",
                    color: .green
                )

                StatCard(
                    title: language.localized("Volumes"),
                    value: "\(volumes.count)",
                    subtitle: language.localized("volumes"),
                    icon: "externaldrive.fill",
                    color: .orange
                )

                StatCard(
                    title: language.localized("Machines"),
                    value: "\(machines.count)",
                    subtitle: "\(machines.filter { $0.status == .running }.count) \(language.localized("running"))",
                    icon: "desktopcomputer",
                    color: .teal
                )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Recent Containers

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.localized("Recent Containers"))
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)

            if containers.isEmpty {
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(language.localized("No containers"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(containers.prefix(5)) { container in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(container.statusColor)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(container.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(container.image)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(container.state.rawValue.capitalized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(container.statusColor)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)

                        if container.id != containers.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Actions

    private func loadDashboard(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            async let systemInfoTask = cliBackend.getSystemInfo()
            async let containersTask = cliBackend.listContainers(all: true)
            async let imagesTask = cliBackend.listImages()
            async let volumesTask = cliBackend.listVolumes()
            async let networksTask = cliBackend.listNetworks()
            async let machinesTask = cliBackend.listMachines()
            systemInfo = try await systemInfoTask
            containers = try await containersTask
            images = try await imagesTask
            volumes = try await volumesTask
            networks = try await networksTask
            machines = try await machinesTask
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    MonitorView()
}
