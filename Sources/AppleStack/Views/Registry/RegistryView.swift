import SwiftUI

struct RegistryView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var output = ""
    @State private var errorMessage: String?
    @State private var server = ""
    @State private var username = ""
    @State private var scheme = "auto"
    @State private var showLoginSheet = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Registry", subtitle: "Manage registry logins") {
                Button("List") { Task { await listRegistries() } }
                    .buttonStyle(.bordered)
                Button("Login") { showLoginSheet = true }
                    .buttonStyle(.borderedProminent)
                Button("Logout") { Task { await logout() } }
                    .buttonStyle(.bordered)
                    .disabled(server.isEmpty)
            }

            if let error = errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await listRegistries() } })
            } else if output.isEmpty {
                EmptyStateView(icon: "key.fill", title: "No registries", subtitle: "Login to a container registry")
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $showLoginSheet) { loginSheet }
        .task { await listRegistries() }
    }

    private var loginSheet: some View {
        Form {
            Section("Registry Login") {
                TextField("Server", text: $server)
                TextField("Username", text: $username)
                TextField("Scheme", text: $scheme)
                Text("Password input is handled by the container CLI when required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 220)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { showLoginSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Login") { Task { await login() } }
                    .disabled(server.isEmpty)
            }
        }
    }

    private func listRegistries() async {
        await run { try await cliBackend.registryList() }
    }

    private func login() async {
        do {
            try await cliBackend.registryLogin(
                server: server,
                username: username.isEmpty ? nil : username,
                scheme: scheme.isEmpty ? nil : scheme,
                passwordStdin: false
            )
            showLoginSheet = false
            await listRegistries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logout() async {
        do {
            try await cliBackend.registryLogout(server: server)
            await listRegistries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func run(_ operation: () async throws -> String) async {
        do {
            errorMessage = nil
            output = try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RegistryView()
}
