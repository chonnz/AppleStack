import SwiftUI

struct SystemStatusView: View {
    @Bindable var viewModel: SystemStatusViewModel
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if viewModel.isLoading && viewModel.systemInfo == nil {
                ProgressView(language.localized("Loading system status..."))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.systemInfo == nil {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(language.localized("System status unavailable"))
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Button(language.localized("Retry")) {
                        Task { await viewModel.loadStatus() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                systemInfoView
            }
        }
        .task {
            await viewModel.loadStatus(showLoading: viewModel.systemInfo == nil)
        }
        .sheet(isPresented: $viewModel.showOutputSheet) {
            InspectOutputSheet(title: viewModel.outputTitle, output: viewModel.outputText)
        }
        .background(AppTheme.chromeBackground)
    }

    private var toolbar: some View {
        PaneHeader(title: language.localized("System"), subtitle: viewModel.osInfo == "Unknown" ? nil : viewModel.osInfo) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    systemStatusPill
                    systemHeaderButtons
                }

                HStack(spacing: 8) {
                    systemHeaderButtons
                }
            }
        }
    }

    private var systemInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                systemSection(language.localized("Overview")) {
                    MonitorView(showsTopBar: false, isEmbedded: true)
                }

                systemSection(language.localized("Commands")) {
                    HStack(spacing: 10) {
                        systemActionButton(language.localized("Version"), icon: "number") {
                            Task { await viewModel.showVersion() }
                        }
                        systemActionButton(language.localized("Disk Usage"), icon: "internaldrive") {
                            Task { await viewModel.showDiskUsage() }
                        }
                        systemActionButton(language.localized("Logs"), icon: "doc.text") {
                            Task { await viewModel.showLogs() }
                        }
                        systemActionButton(language.localized("Properties"), icon: "list.bullet.rectangle") {
                            Task { await viewModel.showProperties() }
                        }
                        systemActionButton(language.localized("DNS"), icon: "network") {
                            Task { await viewModel.showDNS() }
                        }
                    }
                }

                systemSection(language.localized("Management")) {
                    systemManagementView
                }

                systemSection(language.localized("Builder")) {
                    BuilderView(isEmbedded: true)
                }

                systemSection(language.localized("Details")) {
                    detailRows
                }
            }
            .padding(.vertical, 8)
        }
        .background(AppTheme.chromeBackground)
    }

    private var systemStatusPill: some View {
        HeaderPill {
            Circle()
                .fill(viewModel.isRunning ? .green : .red)
                .frame(width: 8, height: 8)
            Text(language.localized(viewModel.isRunning ? "Running" : "Stopped"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(viewModel.isRunning ? .green : .red)
        }
    }

    private var systemHeaderButtons: some View {
        HStack(spacing: 8) {
            HeaderCircleButton(
                systemName: viewModel.isLoading ? "hourglass" : "arrow.clockwise",
                action: { Task { await viewModel.loadStatus(showLoading: false) } },
                helpText: language.localized("Refresh")
            )
            .disabled(viewModel.isLoading || viewModel.isActionRunning)

            HeaderCircleButton(
                systemName: viewModel.isActionRunning ? "hourglass" : "play.fill",
                action: { Task { await viewModel.startSystem() } },
                helpText: language.localized("Start")
            )
            .disabled(viewModel.isRunning || viewModel.isActionRunning)

            HeaderCircleButton(
                systemName: viewModel.isActionRunning ? "hourglass" : "stop.fill",
                action: { Task { await viewModel.stopSystem() } },
                helpText: language.localized("Stop")
            )
            .disabled(!viewModel.isRunning || viewModel.isActionRunning)
        }
    }

    private func systemSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            content()
        }
        .padding(.vertical, 14)
        .background(AppTheme.chromeBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var systemManagementView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.localized("DNS"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField(language.localized("Domain"), text: $viewModel.dnsDomain)
                    TextField(language.localized("Localhost IP (optional)"), text: $viewModel.dnsLocalhost)
                    Button(language.localized("Create")) {
                        Task { await viewModel.createDNS() }
                    }
                    .disabled(viewModel.dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)
                    Button(language.localized("Delete")) {
                        Task { await viewModel.deleteDNS() }
                    }
                    .disabled(viewModel.dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(language.localized("Kernel"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField(language.localized("Kernel path"), text: $viewModel.kernelPath)
                    Button(language.localized("Set")) {
                        Task { await viewModel.setKernel() }
                    }
                    .disabled(viewModel.kernelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActionRunning)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func systemActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let info = viewModel.systemInfo {
                DetailRow(icon: "info.circle", label: language.localized("Version"), value: info.version)
                Divider()
                DetailRow(icon: "desktopcomputer", label: language.localized("OS"), value: info.os)
                Divider()
                DetailRow(icon: "terminal", label: language.localized("Kernel"), value: info.kernel)
                Divider()
                DetailRow(icon: "cpu", label: language.localized("Architecture"), value: info.arch)
            }
        }
        .padding(.horizontal, 16)
    }

    private func DetailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            SwiftUI.Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    SystemStatusView(viewModel: SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    ))
}
