import SwiftUI

struct CreateContainerSheet: View {
    @Bindable var viewModel: ContainerListViewModel
    @State private var config = ContainerConfig()
    @State private var envKey = ""
    @State private var envValue = ""
    @State private var volumeSource = ""
    @State private var volumeDest = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Basic Settings") {
                TextField("Container Name", text: $config.name)
                TextField("Image (e.g., nginx:latest)", text: $config.image)
            }

            Section("Resources") {
                Stepper("CPUs: \(config.cpus)", value: $config.cpus, in: 1...16)
                TextField("Memory (e.g., 512m, 2g)", text: $config.memory)
            }

            Section("Network") {
                TextField("Port Mapping (e.g., 8080:80)", text: $config.ports)
            }

            Section("Environment Variables") {
                envVarsList
                addEnvVarRow
            }

            Section("Volumes") {
                volumesList
                addVolumeRow
            }

            Section("Options") {
                Toggle("Run in background (--detach)", isOn: $config.detach)
                Toggle("Interactive mode (-i)", isOn: $config.interactive)
                Toggle("Allocate TTY (-t)", isOn: $config.tty)
                Toggle("Auto-remove (--rm)", isOn: $config.autoRemove)
                TextField("DNS (e.g., 8.8.8.8)", text: $config.dns)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 500)
        .navigationTitle("Create Container")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await viewModel.createContainer(config: config)
                    }
                }
                .disabled(config.name.isEmpty || config.image.isEmpty)
            }
        }
    }

    private var envVarsList: some View {
        ForEach(Array(config.env.keys.sorted()), id: \.self) { key in
            let value = config.env[key] ?? ""
            HStack {
                Text(key)
                    .font(.system(size: 12, design: .monospaced))
                Text("=")
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button {
                    config.env.removeValue(forKey: key)
                } label: {
                    SwiftUI.Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addEnvVarRow: some View {
        HStack {
            TextField("Key", text: $envKey)
                .textFieldStyle(.roundedBorder)
            TextField("Value", text: $envValue)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !envKey.isEmpty else { return }
                config.env[envKey] = envValue
                envKey = ""
                envValue = ""
            } label: {
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(envKey.isEmpty)
        }
    }

    private var volumesList: some View {
        ForEach(config.volumes, id: \.self) { volume in
            HStack {
                SwiftUI.Image(systemName: "externaldrive")
                    .foregroundStyle(.secondary)
                Text(volume)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button {
                    config.volumes.removeAll { $0 == volume }
                } label: {
                    SwiftUI.Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addVolumeRow: some View {
        HStack {
            TextField("Host Path", text: $volumeSource)
                .textFieldStyle(.roundedBorder)
            Text(":")
                .foregroundStyle(.secondary)
            TextField("Container Path", text: $volumeDest)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !volumeSource.isEmpty, !volumeDest.isEmpty else { return }
                config.volumes.append("\(volumeSource):\(volumeDest)")
                volumeSource = ""
                volumeDest = ""
            } label: {
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(volumeSource.isEmpty || volumeDest.isEmpty)
        }
    }
}

#Preview {
    CreateContainerSheet(viewModel: ContainerListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
