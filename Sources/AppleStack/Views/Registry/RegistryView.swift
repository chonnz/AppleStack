import SwiftUI

struct RegistryEntry: Codable, Identifiable {
    var id: String { server }
    let server: String
    let username: String?
    let scheme: String?
}

struct RegistryView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var entries: [RegistryEntry] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var server = ""
    @State private var username = ""
    @State private var scheme = "auto"
    @State private var showLoginSheet = false
    @State private var selectedServer: String?
    @State private var isActionRunning = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: language.localized("Registry"), subtitle: "\(entries.count) \(language.localized(entries.count == 1 ? "login" : "logins"))") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        registryHeaderButtons
                    }
                    HStack(spacing: 8) {
                        HeaderCircleButton(
                            systemName: isActionRunning ? "hourglass" : "plus",
                            action: { showLoginSheet = true },
                            helpText: language.localized("Login")
                        )
                        .disabled(isActionRunning)

                        HeaderMenuButton(helpText: language.localized("More actions")) {
                            registryMenuActions
                        }
                    }
                }
            }

            if let error = errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await loadRegistries() } })
            } else if entries.isEmpty && !isLoading {
                EmptyStateView(icon: "key.fill", title: language.localized("No registries"), subtitle: language.localized("Login to a container registry"))
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(language.localized("Registries"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(entries.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 2)

                        ForEach(entries) { entry in
                            registryRow(entry)
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $showLoginSheet) { loginSheet }
        .task { await loadRegistries() }
    }

    private var registryHeaderButtons: some View {
        HStack(spacing: 8) {
            HeaderCircleButton(
                systemName: isLoading ? "hourglass" : "arrow.clockwise",
                action: { Task { await loadRegistries() } },
                helpText: language.localized("Refresh")
            )
            .disabled(isLoading || isActionRunning)

            HeaderCircleButton(
                systemName: isActionRunning ? "hourglass" : "plus",
                action: { showLoginSheet = true },
                helpText: language.localized("Login")
            )
            .disabled(isActionRunning)

            HeaderCircleButton(
                systemName: isActionRunning ? "hourglass" : "rectangle.portrait.and.arrow.right",
                action: { Task { await logout() } },
                helpText: language.localized("Logout")
            )
            .disabled(selectedServer == nil || isActionRunning)
        }
    }

    @ViewBuilder
    private var registryMenuActions: some View {
        Button(language.localized("Refresh")) {
            Task { await loadRegistries() }
        }
        .disabled(isLoading || isActionRunning)
        Button(language.localized("Logout")) {
            Task { await logout() }
        }
        .disabled(selectedServer == nil || isActionRunning)
    }

    @ViewBuilder
    private func registryRow(_ entry: RegistryEntry) -> some View {
        let isSelected = selectedServer == entry.server
        HStack(spacing: 12) {
            SwiftUI.Image(systemName: "tray.full")
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? Color.white : AppTheme.accentColor)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.white.opacity(0.16) : AppTheme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.server)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                if let username = entry.username, !username.isEmpty {
                    Text("\(language.localized("Logged in as")) \(username)")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.78) : Color.secondary)
                }
            }

            Spacer()

            if let scheme = entry.scheme {
                Text(scheme)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.white.opacity(0.16) : AppTheme.chromeBackground)
                    .clipShape(Capsule())
            }

            SwiftUI.Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.clear)
                .frame(width: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? AppTheme.listSelection : AppTheme.chromeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.clear : AppTheme.subtleBorder, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            selectedServer = selectedServer == entry.server ? nil : entry.server
        }
    }

    private var loginSheet: some View {
        Form {
            Section(language.localized("Registry Login")) {
                TextField(language.localized("Server"), text: $server)
                TextField(language.localized("Username"), text: $username)
                TextField(language.localized("Scheme"), text: $scheme)
                Text(language.localized("Password input is handled by the container CLI when required."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 220)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) { showLoginSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isActionRunning ? language.localized("Working...") : language.localized("Login")) { Task { await login() } }
                    .disabled(server.isEmpty || isActionRunning)
            }
        }
    }

    private func loadRegistries(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            let raw = try await cliBackend.registryList()
            entries = parseRegistryList(raw)
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }

    private func parseRegistryList(_ raw: String) -> [RegistryEntry] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let data = trimmed.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let array = try? decoder.decode([RegistryEntry].self, from: data) {
                return array
            }
        }

        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var entries: [RegistryEntry] = []
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            if parts.count >= 1 {
                entries.append(RegistryEntry(
                    server: parts[0],
                    username: parts.count >= 2 ? parts[1] : nil,
                    scheme: parts.count >= 3 ? parts[2] : nil
                ))
            }
        }
        return entries
    }

    private func login() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await cliBackend.registryLogin(
                server: server,
                username: username.isEmpty ? nil : username,
                scheme: scheme.isEmpty ? nil : scheme,
                passwordStdin: false
            )
            showLoginSheet = false
            await loadRegistries(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadRegistries(showLoading: false)
        }
    }

    private func logout() async {
        guard let server = selectedServer else { return }
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await cliBackend.registryLogout(server: server)
            selectedServer = nil
            await loadRegistries(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadRegistries(showLoading: false)
        }
    }
}

#Preview {
    RegistryView()
}
