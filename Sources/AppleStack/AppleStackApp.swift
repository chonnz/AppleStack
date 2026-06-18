import SwiftUI

@main
struct AppleStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let cliBackend: ContainerServiceProtocol = CLIBackend()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.cliBackend, cliBackend)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environment(\.cliBackend, cliBackend)
        }

        MenuBarExtra("AppleStack", systemImage: "shippingbox") {
            MenuBarView()
                .environment(\.cliBackend, cliBackend)
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
