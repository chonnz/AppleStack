import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection = .dashboard
    @State private var containerViewModel = ContainerListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var imageViewModel = ImageListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var systemViewModel = SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var selectedContainer: Container?
    @State private var selectedImage: Image?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedSection: $selectedSection)

            Divider()

            // Main content area
            HStack(spacing: 0) {
                // List panel
                Group {
                    switch selectedSection {
                    case .dashboard:
                        MonitorView()
                    case .containers:
                        ContainerListView(
                            viewModel: containerViewModel,
                            selectedContainer: $selectedContainer
                        )
                    case .images:
                        ImageListView(
                            viewModel: imageViewModel,
                            selectedImage: $selectedImage
                        )
                    case .volumes:
                        VolumeListView()
                    case .networks:
                        NetworkListView()
                    case .machines:
                        MachineListView()
                    case .system:
                        SystemStatusView(viewModel: systemViewModel)
                    }
                }
                .frame(minWidth: 320, idealWidth: 380)

                // Detail panel (only for containers and images)
                if selectedSection == .containers || selectedSection == .images {
                    Divider()

                    DetailPanel(
                        section: selectedSection,
                        selectedContainer: selectedContainer,
                        selectedImage: selectedImage
                    )
                    .frame(minWidth: 400)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
    }
}

private struct DetailPanel: View {
    let section: AppSection
    let selectedContainer: Container?
    let selectedImage: Image?

    var body: some View {
        if let container = selectedContainer, section == .containers {
            ContainerDetailView(container: container)
        } else if let image = selectedImage, section == .images {
            ImageDetailView(image: image)
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
}

private struct ImageDetailView: View {
    let image: Image

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                Text("Info")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(label: "Repository", value: image.repository)
                        InfoRow(label: "Tag", value: image.tag)
                        InfoRow(label: "ID", value: image.id)
                        InfoRow(label: "Size", value: image.sizeFormatted)
                        InfoRow(label: "Created", value: image.created)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(16)
            }
        }
        .background(.white)
    }
}

#Preview {
    ContentView()
}
