import SwiftUI

struct SettingsView: View {
    @State private var cliPath = UserDefaults.standard.string(forKey: "cliPath") ?? "/usr/local/bin/container"
    @State private var refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
    @State private var showAllContainers = UserDefaults.standard.bool(forKey: "showAllContainers")

    var body: some View {
        Form {
            Section("CLI") {
                HStack {
                    Text("Container CLI path:")
                    TextField("Path", text: $cliPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            cliPath = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonStyle(.bordered)
                }

                HStack {
                    Text("Refresh interval (seconds):")
                    Stepper("\(Int(refreshInterval))s", value: $refreshInterval, in: 5...60, step: 5)
                }
            }

            Section("Display") {
                Toggle("Show all containers by default", isOn: $showAllContainers)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text("2024.1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .navigationTitle("Settings")
        .onAppear {
            refreshInterval = max(refreshInterval, 10)
        }
        .onDisappear {
            // 保存设置
            UserDefaults.standard.set(cliPath, forKey: "cliPath")
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            UserDefaults.standard.set(showAllContainers, forKey: "showAllContainers")
        }
    }
}

#Preview {
    SettingsView()
}
