import SwiftUI

struct SystemStatusView: View {
    @Bindable var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if viewModel.isLoading {
                ProgressView("Loading system status...")
                    .padding()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text("System status unavailable")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Button("Retry") {
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
            await viewModel.loadStatus()
        }
        .sheet(isPresented: $viewModel.showOutputSheet) {
            InspectOutputSheet(title: viewModel.outputTitle, output: viewModel.outputText)
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isRunning ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isRunning ? "Running" : "Stopped")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(viewModel.isRunning ? .green : .red)
                    }
                    Text(viewModel.osInfo)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.startSystem() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                Button {
                    Task { await viewModel.stopSystem() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
        }
        .background(AppTheme.paneBackground)
    }

    private var systemInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Quick stats
                HStack(spacing: 12) {
                    statCard(icon: "play.circle", value: "\(viewModel.systemInfo?.containersRunning ?? 0)", label: "Running")
                    statCard(icon: "stop.circle", value: "\(viewModel.systemInfo?.containersStopped ?? 0)", label: "Stopped")
                    statCard(icon: "photo.stack", value: "\(viewModel.systemInfo?.images ?? 0)", label: "Images")
                }

                Divider()

                HStack(spacing: 10) {
                    systemActionButton("Version", icon: "number") {
                        Task { await viewModel.showVersion() }
                    }
                    systemActionButton("Disk Usage", icon: "internaldrive") {
                        Task { await viewModel.showDiskUsage() }
                    }
                    systemActionButton("Logs", icon: "doc.text") {
                        Task { await viewModel.showLogs() }
                    }
                    systemActionButton("Properties", icon: "list.bullet.rectangle") {
                        Task { await viewModel.showProperties() }
                    }
                }

                Divider()

                // Detailed info
                VStack(alignment: .leading, spacing: 0) {
                    if let info = viewModel.systemInfo {
                        DetailRow(icon: "info.circle", label: "Version", value: info.version)
                        Divider()
                        DetailRow(icon: "desktopcomputer", label: "OS", value: info.os)
                        Divider()
                        DetailRow(icon: "terminal", label: "Kernel", value: info.kernel)
                        Divider()
                        DetailRow(icon: "cpu", label: "Architecture", value: info.arch)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func systemActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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
