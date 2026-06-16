import SwiftUI

struct PullImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @State private var imageName = ""
    @State private var isPulling = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Image") {
                TextField("Image name (e.g., nginx:latest)", text: $imageName)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    SwiftUI.Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Enter the full image name including tag (e.g., nginx:latest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 180)
        .navigationTitle("Pull Image")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    isPulling = true
                    Task {
                        await viewModel.pullImage(name: imageName)
                        isPulling = false
                        dismiss()
                    }
                } label: {
                    if isPulling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Pull")
                    }
                }
                .disabled(imageName.isEmpty || isPulling)
            }
        }
    }
}

#Preview {
    PullImageSheet(viewModel: ImageListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
