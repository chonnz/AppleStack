import SwiftUI

struct MachineDetailView: View {
    let machine: Machine
    let selectedTab: String

    @StateObject private var terminalSession: PersistentTerminalSession
    @State private var inspectOutput: String?
    @State private var isLoadingInspect = false
    @State private var inspectError: String?

    private let cliBackend = CLIBackend()

    init(machine: Machine, selectedTab: String) {
        self.machine = machine
        self.selectedTab = selectedTab
        self._terminalSession = StateObject(wrappedValue: PersistentTerminalSession(
            target: .machine(id: machine.id)
        ))
    }

    var body: some View {
        Group {
            switch selectedTab {
            case "Resources":
                resourcesView
            case "Terminal":
                terminalView
            case "Inspect":
                inspectView
            default:
                infoView
            }
        }
        .background(AppTheme.paneBackground)
        .task(id: machine.id) {
            await loadInspectDetails()
        }
    }

    private var infoView: some View {
        Group {
            if isLoadingInspect && inspectOutput == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        InspectorSection(title: "Overview") {
                            InspectorCard {
                                InspectorRows(rows: [
                                    .init(label: "Name", value: machine.name),
                                    .init(label: "ID", value: machine.id, usesMonospacedFont: true),
                                    .init(label: "Status", value: machine.status.rawValue),
                                    .init(label: "Image", value: machine.image, usesMonospacedFont: true),
                                    .init(label: "Created", value: machine.created),
                                ].filter(\.hasContent))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var resourcesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Resources") {
                    InspectorCard {
                        InspectorRows(rows: [
                            .init(label: "CPUs", value: "\(machine.cpus)"),
                            .init(label: "Memory", value: machine.memory),
                            .init(label: "Disk", value: machine.disk),
                            .init(label: "IP Address", value: machine.ip),
                        ].filter(\.hasContent))
                    }
                }

                if let inspectError {
                    InspectorSection(title: "Diagnostics") {
                        InspectorCard {
                            Text(inspectError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var terminalView: some View {
        NativeTerminalView(
            sessionTitle: "Machine Terminal",
            sessionSubtitle: machine.name,
            prompt: "\(machine.name) %",
            placeholder: "Enter shell command",
            isAvailable: machine.status == .running,
            unavailableTitle: "Machine is not running",
            unavailableMessage: "Start the machine to access the terminal.",
            showsMacTerminalButton: true,
            session: terminalSession
        )
    }

    private var inspectView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Inspect") {
                    InspectorCard {
                        Text(inspectOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? inspectOutput! : "No inspect output available")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let inspectError {
                    InspectorSection(title: "Diagnostics") {
                        InspectorCard {
                            Text(inspectError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func loadInspectDetails() async {
        isLoadingInspect = true
        inspectError = nil

        do {
            inspectOutput = try await cliBackend.inspectMachine(id: machine.id)
        } catch {
            inspectOutput = nil
            inspectError = error.localizedDescription
        }

        isLoadingInspect = false
    }

}

#Preview {
    MachineDetailView(machine: Machine(
        id: "abc123",
        name: "my-machine",
        status: .running,
        image: "ubuntu:latest",
        cpus: 2,
        memory: "2g",
        disk: "20g",
        ip: "192.168.64.2"
    ), selectedTab: "Info")
}
