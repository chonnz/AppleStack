import SwiftUI

struct ContentView: View {
    @State private var selectedSection: SidebarSection = .containers
    @State private var containerViewModel = ContainerListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var imageViewModel = ImageListViewModel(
        service: ContainerServiceFactory.create()
    )
    @State private var systemViewModel = SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    )

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .containers:
                ContainerListView(viewModel: containerViewModel)
            case .images:
                ImageListView(viewModel: imageViewModel)
            case .system:
                SystemStatusView(viewModel: systemViewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
}
