import SwiftUI

@main
struct AppleStackApp: App {
    @State private var systemViewModel = SystemStatusViewModel(
        service: ContainerServiceFactory.create()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        MenuBarExtra("AppleStack", systemImage: "shippingbox") {
            MenuBarView(viewModel: systemViewModel)
        }
    }
}
