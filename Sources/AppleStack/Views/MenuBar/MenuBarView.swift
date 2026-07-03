import SwiftUI

struct MenuBarView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var viewModel = SystemStatusViewModel(service: ContainerServiceFactory.create())
    @State private var containers: [Container] = []
    @State private var machines: [Machine] = []
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

            if !machines.isEmpty {
                Divider()

                Text(language.localized("Machines"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(machines) { machine in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(machine.status == .running ? .green : .gray)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(machine.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(machine.status.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if machine.status == .running {
                            Button(language.localized("Stop")) {
                                Task {
                                    try? await cliBackend.stopMachine(id: machine.id)
                                    await loadMachines()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        } else {
                            Button(language.localized("Start")) {
                                Task {
                                    try? await cliBackend.startMachine(id: machine.id)
                                    await loadMachines()
                                }
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

            Button(language.localized("Refresh")) {
                Task {
                    await viewModel.loadStatus()
                    await loadContainers()
                    await loadMachines()
                }
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
        .frame(width: 280)
        .task {
            await viewModel.loadStatus()
            await loadContainers()
            await loadMachines()
        }
    }

    private func loadContainers() async {
        containers = (try? await cliBackend.listContainers(all: false)) ?? []
    }

    private func loadMachines() async {
        machines = (try? await cliBackend.listMachines()) ?? []
    }
}

#Preview {
    MenuBarView()
}
