import SwiftUI

@main
struct AppleStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceStore = ContainerServiceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.cliBackend, serviceStore.service)
                .id(serviceStore.generation)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(onCLIPathChanged: serviceStore.refreshBackend)
                .environment(\.cliBackend, serviceStore.service)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("AppleStack", systemImage: "shippingbox") {
            MenuBarView()
                .environment(\.cliBackend, serviceStore.service)
                .id(serviceStore.generation)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保窗口显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
