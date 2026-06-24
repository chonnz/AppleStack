import SwiftUI

struct BuilderInstance: Codable, Identifiable {
    var id: String { name }
    let name: String
    let driver: String?
    let status: String?
    let nodes: [BuilderNode]?
}

struct BuilderNode: Codable, Identifiable {
    var id: String { name }
    let name: String
    let status: String?
    let platforms: [String]?
}

struct BuilderView: View {
    let isEmbedded: Bool
    @Environment(\.cliBackend) private var cliBackend
    @State private var instances: [BuilderInstance] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isActionRunning = false
    @State private var showDeleteConfirmation = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private var isRunning: Bool {
        instances.contains { $0.status?.localizedCaseInsensitiveContains("running") == true }
    }

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    var body: some View {
        Group {
            if isEmbedded {
                embeddedContent
            } else {
                standaloneContent
            }
        }
        .background(AppTheme.paneBackground)
        .task { await loadStatus() }
        .confirmationDialog(language.localized("Delete builder?"), isPresented: $showDeleteConfirmation) {
            Button(language.localized("Delete"), role: .destructive) {
                Task { await delete() }
            }
            Button(language.localized("Cancel"), role: .cancel) {}
        } message: {
            Text(language.localized("This removes the current builder instance. Existing images are not deleted."))
        }
    }

    private var standaloneContent: some View {
        VStack(spacing: 0) {
            PaneHeader(title: language.localized("Builder"), subtitle: language.localized(isRunning ? "Running" : "Stopped")) {
                actionButtons
            }

            ScrollView {
                builderContent
                    .padding(16)
            }
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.localized("Builder"))
                        .font(.system(size: 14, weight: .semibold))
                    builderStatusLine
                }

                Spacer()

                actionButtons
            }

            builderContent
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var builderContent: some View {
        if let error = errorMessage {
            ErrorStateView(message: error, retryAction: { Task { await loadStatus() } })
        } else if instances.isEmpty && !isLoading {
            if isEmbedded {
                compactEmptyBuilder
            } else {
                EmptyStateView(icon: "hammer", title: language.localized("Builder"), subtitle: language.localized("Start the builder to begin building images"))
            }
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(instances) { instance in
                    builderCard(instance)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            builderIconButton(isLoading ? "hourglass" : "arrow.clockwise", help: language.localized("Refresh")) {
                Task { await loadStatus() }
            }
            .disabled(isLoading || isActionRunning)

            builderIconButton(isActionRunning ? "hourglass" : "play.fill", help: language.localized("Start")) {
                Task { await start() }
            }
            .disabled(isRunning || isActionRunning)

            builderIconButton(isActionRunning ? "hourglass" : "stop.fill", help: language.localized("Stop")) {
                Task { await stop() }
            }
            .disabled(!isRunning || isActionRunning)

            builderIconButton("trash", role: .destructive, help: language.localized("Delete")) {
                showDeleteConfirmation = true
            }
            .disabled(isActionRunning)
        }
    }

    private var builderStatusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green : Color.secondary.opacity(0.65))
                .frame(width: 7, height: 7)
            Text(language.localized(isRunning ? "Running" : "Stopped"))
                .font(.system(size: 12))
                .foregroundStyle(isRunning ? .green : .secondary)
            if isActionRunning {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var compactEmptyBuilder: some View {
        HStack(spacing: 12) {
            SwiftUI.Image(systemName: "hammer")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(AppTheme.chromeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(language.localized("No builder instance"))
                    .font(.system(size: 13, weight: .semibold))
                Text(language.localized("Start the builder before building images."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.chromeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func builderIconButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .background(AppTheme.chromeBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func builderCard(_ instance: BuilderInstance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill((instance.status?.localizedCaseInsensitiveContains("running") == true) ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(instance.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let status = instance.status {
                    Text(status.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(AppTheme.chromeBackground)
                        .clipShape(Capsule())
                }
            }

            if let driver = instance.driver {
                HStack(spacing: 6) {
                    SwiftUI.Image(systemName: "gearshape.2")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("\(language.localized("Driver")): \(driver)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if let nodes = instance.nodes, !nodes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.localized("Nodes"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(nodes) { node in
                        HStack(spacing: 8) {
                            Circle()
                                .fill((node.status?.localizedCaseInsensitiveContains("running") == true) ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text(node.name)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            if let platforms = node.platforms {
                                Text(platforms.joined(separator: ", "))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func loadStatus(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            let raw = try await cliBackend.builderStatus(format: "json")
            instances = try parseBuilderStatus(raw)
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }

    private func parseBuilderStatus(_ raw: String) throws -> [BuilderInstance] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let data = trimmed.data(using: .utf8) else { return [] }

        if let array = try? JSONDecoder().decode([BuilderInstance].self, from: data) {
            return array
        }
        if let single = try? JSONDecoder().decode(BuilderInstance.self, from: data) {
            return [single]
        }
        return []
    }

    private func start() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            errorMessage = nil
            try await cliBackend.builderStart()
            await loadStatus(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadStatus(showLoading: false)
        }
    }

    private func stop() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            errorMessage = nil
            try await cliBackend.builderStop()
            await loadStatus(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadStatus(showLoading: false)
        }
    }

    private func delete() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            errorMessage = nil
            try await cliBackend.builderDelete()
            await loadStatus(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadStatus(showLoading: false)
        }
    }
}

#Preview {
    BuilderView()
}
