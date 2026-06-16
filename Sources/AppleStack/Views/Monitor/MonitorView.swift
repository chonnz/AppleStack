import SwiftUI

struct MonitorView: View {
    @State private var systemInfo: SystemInfo?
    @State private var containers: [Container] = []
    @State private var images: [Image] = []
    @State private var networks: [Network] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let cliBackend = CLIBackend()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dashboard")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("System overview and monitoring")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if isLoading {
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
                        Button("Retry") {
                            Task { await loadDashboard() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    // Stats cards
                    statsSection

                    // Resource usage
                    resourceSection

                    // Recent activity
                    activitySection
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await loadDashboard()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                StatCard(
                    title: "Containers",
                    value: "\(containers.count)",
                    subtitle: "\(containers.filter { $0.state == .running }.count) running",
                    icon: "shippingbox.fill",
                    color: .blue
                )

                StatCard(
                    title: "Images",
                    value: "\(images.count)",
                    subtitle: "local images",
                    icon: "photo.stack.fill",
                    color: .purple
                )

                StatCard(
                    title: "Networks",
                    value: "\(networks.count)",
                    subtitle: "networks",
                    icon: "network",
                    color: .green
                )

                StatCard(
                    title: "System",
                    value: systemInfo?.version ?? "N/A",
                    subtitle: systemInfo?.os ?? "",
                    icon: "gearshape.fill",
                    color: .orange
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Resource Section

    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Information")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 0) {
                if let info = systemInfo {
                    InfoRow(label: "Version", value: info.version)
                    InfoRow(label: "OS", value: info.os)
                    InfoRow(label: "Kernel", value: info.kernel)
                    InfoRow(label: "Architecture", value: info.arch)
                    InfoRow(label: "Running Containers", value: "\(info.containersRunning)")
                    InfoRow(label: "Stopped Containers", value: "\(info.containersStopped)")
                    InfoRow(label: "Images", value: "\(info.images)")
                } else {
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Containers")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)

            if containers.isEmpty {
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No containers")
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

    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            async let systemInfoTask = cliBackend.getSystemInfo()
            async let containersTask = cliBackend.listContainers(all: true)
            async let imagesTask = cliBackend.listImages()
            async let networksTask = cliBackend.listNetworks()

            systemInfo = try await systemInfoTask
            containers = try await containersTask
            images = try await imagesTask
            networks = try await networksTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
        .frame(width: 180, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    MonitorView()
}
