import SwiftUI

struct MenuBarView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var viewModel = SystemStatusViewModel(service: ContainerServiceFactory.create())
    @State private var containers: [Container] = []
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(language.localized(viewModel.isRunning ? "Running" : "Stopped"))
                    .font(.headline)
                Spacer()
            }

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

            if !containers.isEmpty {
                Divider()

                Text(language.localized("Containers"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(containers) { container in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(container.statusColor)
                            .frame(width: 6, height: 6)
                        Text(container.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if container.state == .running {
                            Button(language.localized("Stop")) {
                                Task { try? await cliBackend.stopContainer(id: container.id) }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        } else {
                            Button(language.localized("Start")) {
                                Task { try? await cliBackend.startContainer(id: container.id) }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        }
                    }
                }
            }

            Divider()

            Button(language.localized("Open AppleStack")) {
                NSApp.activate(ignoringOtherApps: true)
            }

            Button(language.localized(viewModel.isRunning ? "Stop System" : "Start System")) {
                Task {
                    if viewModel.isRunning {
                        try? await cliBackend.systemStop()
                    } else {
                        try? await cliBackend.systemStart()
                    }
                    await viewModel.loadStatus()
                }
            }

            Divider()

            Button(language.localized("Quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 240)
        .task {
            await viewModel.loadStatus()
            await loadContainers()
        }
    }

    private func loadContainers() async {
        containers = (try? await cliBackend.listContainers(all: false)) ?? []
    }
}

#Preview {
    MenuBarView()
}
