import SwiftUI

struct PullImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @State private var imageName = ""
    @State private var isPulling = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Image")) {
                TextField(language.localized("Image name (e.g., nginx:latest)"), text: $imageName)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    SwiftUI.Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(language.localized("Enter the full image name including tag (e.g., nginx:latest)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 180)
        .navigationTitle(language.localized("Pull Image"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) {
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
                        Text(language.localized("Pull"))
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
