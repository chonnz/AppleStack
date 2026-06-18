import SwiftUI

struct RegistryView: View {
    @State private var output = ""
    @State private var errorMessage: String?
    @State private var server = ""
    @State private var username = ""
    @State private var scheme = "auto"
    @State private var showLoginSheet = false
    private let cliBackend = CLIBackend()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            outputView
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $showLoginSheet) {
            loginSheet
        }
        .task {
            await listRegistries()
        }
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Registry")
                    .font(.system(size: 16, weight: .semibold))
                Text("Manage registry logins")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("List") { Task { await listRegistries() } }
                .buttonStyle(.bordered)
            Button("Login") { showLoginSheet = true }
                .buttonStyle(.borderedProminent)
            Button("Logout") { Task { await logout() } }
                .buttonStyle(.bordered)
                .disabled(server.isEmpty)
        }
        .padding(16)
        .background(AppTheme.paneBackground)
    }

    private var outputView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(errorMessage ?? (output.isEmpty ? "No registry output" : output))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(errorMessage == nil ? Color.primary : Color.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
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
