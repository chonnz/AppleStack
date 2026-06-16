import SwiftUI

struct CreateContainerSheet: View {
    @Bindable var viewModel: ContainerListViewModel
    @State private var config = ContainerConfig()
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

            Section("Options") {
                Toggle("Run in background", isOn: $config.detach)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 350)
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
}

#Preview {
    CreateContainerSheet(viewModel: ContainerListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
