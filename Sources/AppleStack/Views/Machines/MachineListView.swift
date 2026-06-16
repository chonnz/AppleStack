import SwiftUI

struct MachineListView: View {
    @State private var machines: [Machine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newMachine = MachineConfig()
    @State private var selectedMachine: Machine?

    private let cliBackend = CLIBackend()

    var body: some View {
        HStack(spacing: 0) {
            // Machine list
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Machines")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(machines.count) machines")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showCreateSheet = true
                    } label: {
                        SwiftUI.Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        SwiftUI.Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadMachines() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if machines.isEmpty {
                    VStack(spacing: 12) {
                        SwiftUI.Image(systemName: "desktopcomputer")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No machines")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    machineList
                }
            }
            .frame(minWidth: 280, idealWidth: 320)

            Divider()

            // Machine detail
            if let machine = selectedMachine {
                MachineDetailView(machine: machine)
            } else {
                VStack {
                    Spacer()
                    Text("No Selection")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showCreateSheet) {
            createMachineSheet
        }
        .task {
            await loadMachines()
        }
    }

    private var machineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(machines) { machine in
                    MachineRowView(
                        machine: machine,
                        isSelected: selectedMachine?.id == machine.id,
                        onStart: { Task { await startMachine(machine) } },
                        onStop: { Task { await stopMachine(machine) } },
                        onDelete: { Task { await deleteMachine(machine) } }
                    )
                    .onTapGesture {
                        selectedMachine = machine
                    }

                    Divider()
                        .padding(.leading, 48)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var createMachineSheet: some View {
        Form {
            Section("Basic Settings") {
                TextField("Machine Name", text: $newMachine.name)
                TextField("Image (e.g., ubuntu:latest)", text: $newMachine.image)
            }

            Section("Resources") {
                Stepper("CPUs: \(newMachine.cpus)", value: $newMachine.cpus, in: 1...16)
                TextField("Memory (e.g., 2g, 4g)", text: $newMachine.memory)
                TextField("Disk (e.g., 20g, 50g)", text: $newMachine.disk)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
        .navigationTitle("Create Machine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showCreateSheet = false
                    newMachine = MachineConfig()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await createMachine(newMachine)
                        showCreateSheet = false
                        newMachine = MachineConfig()
                    }
                }
                .disabled(newMachine.name.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func loadMachines() async {
        isLoading = true
        errorMessage = nil
        do {
            machines = try await cliBackend.listMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createMachine(_ config: MachineConfig) async {
        do {
            try await cliBackend.createMachine(config: config)
            await loadMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startMachine(_ machine: Machine) async {
        do {
            try await cliBackend.startMachine(id: machine.id)
            await loadMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopMachine(_ machine: Machine) async {
        do {
            try await cliBackend.stopMachine(id: machine.id)
            await loadMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMachine(_ machine: Machine) async {
        do {
            try await cliBackend.removeMachine(id: machine.id)
            if selectedMachine?.id == machine.id {
                selectedMachine = nil
            }
            await loadMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    MachineListView()
}
