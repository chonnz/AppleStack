import SwiftUI

struct SystemStatusView: View {
    @Bindable var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading system status...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    SwiftUIImage(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.loadStatus() }
                    }
                }
                Spacer()
            } else {
                systemInfoView
            }
        }
        .navigationTitle("System Status")
        .task {
            await viewModel.loadStatus()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.version)
                    .font(.headline)
                Text(viewModel.osInfo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                statusIndicator

                Button {
                    Task { await viewModel.startSystem() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(viewModel.isRunning)

                Button {
                    Task { await viewModel.stopSystem() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.isRunning)
            }
        }
        .padding()
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isRunning ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isRunning ? "Running" : "Stopped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var systemInfoView: some View {
        List {
            Section("System Information") {
                if let info = viewModel.systemInfo {
                    InfoRow(label: "Version", value: info.version)
                    InfoRow(label: "Operating System", value: info.os)
                    InfoRow(label: "Kernel", value: info.kernel)
                    InfoRow(label: "Architecture", value: info.arch)
                }
            }

            Section("Containers") {
                if let info = viewModel.systemInfo {
                    InfoRow(label: "Running", value: "\(info.containersRunning)")
                    InfoRow(label: "Stopped", value: "\(info.containersStopped)")
                    InfoRow(label: "Total", value: "\(info.containersRunning + info.containersStopped)")
                }
            }

            Section("Images") {
                if let info = viewModel.systemInfo {
                    InfoRow(label: "Total Images", value: "\(info.images)")
                }
            }
        }
        .listStyle(.inset)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SystemStatusView(viewModel: SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    ))
}