import SwiftUI

struct PullImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @State private var imageName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Image") {
                TextField("Image name (e.g., nginx:latest)", text: $imageName)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 350, minHeight: 150)
        .navigationTitle("Pull Image")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Pull") {
                    Task {
                        await viewModel.pullImage(name: imageName)
                        dismiss()
                    }
                }
                .disabled(imageName.isEmpty)
            }
        }
    }
}

#Preview {
    PullImageSheet(viewModel: ImageListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
