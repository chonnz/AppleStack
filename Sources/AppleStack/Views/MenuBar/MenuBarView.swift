import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(viewModel.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isRunning ? "Running" : "Stopped")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Label(viewModel.version, systemImage: "info.circle")
                    .font(.subheadline)
                Label(viewModel.osInfo, systemImage: "desktopcomputer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Start System") {
                Task { await viewModel.startSystem() }
            }
            .disabled(viewModel.isRunning)

            Button("Stop System") {
                Task { await viewModel.stopSystem() }
            }
            .disabled(!viewModel.isRunning)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 200)
        .task {
            await viewModel.loadStatus()
        }
    }
}

#Preview {
    MenuBarView(viewModel: SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    ))
}
