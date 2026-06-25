import SwiftUI

struct VolumeListView: View {
    @Binding var selectedVolume: String?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var volumes: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newVolumeName = ""
    @State private var outputTitle = ""
    @State private var outputText = ""
    @State private var showOutputSheet = false
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var volumeToDelete: String?
    @State private var showPruneConfirmation = false
    @State private var pendingVolumes: Set<String> = []
    @State private var isVolumeActionRunning = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let cliBackend = CLIBackend()

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: language.localized("Volumes"),
                subtitle: "\(volumes.count) \(language.localized("volumes"))",
                leadingAccessory: nil,
                leadingInset: showsSidebarToggle ? AppTheme.windowControlsClearance : 0
            ) {
                headerActions
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(language.localized("Retry")) {
                        Task { await loadVolumes() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if volumes.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "externaldrive")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No volumes"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredVolumes.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No matching volumes"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredVolumes, id: \.self) { volume in
                            VolumeRowView(
                                volume: volume,
                                isSelected: selectedVolume == volume,
                                isPending: pendingVolumes.contains(volume),
                                language: language,
                                onDelete: { volumeToDelete = volume },
                                onInspect: { Task { await inspectVolume(volume) } }
                            )
                            .onTapGesture {
                                selectedVolume = volume
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $showCreateSheet) {
            createVolumeSheet
        }
        .confirmationDialog(
            "Delete volume \"\(volumeToDelete ?? "")\"?",
            isPresented: .init(
                get: { volumeToDelete != nil },
                set: { if !$0 { volumeToDelete = nil } }
            )
        ) {
            Button(language.localized("Delete"), role: .destructive) {
                if let v = volumeToDelete {
                    deleteVolume(v)
                }
                volumeToDelete = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                volumeToDelete = nil
            }
        } message: {
            Text(language.localized("This action cannot be undone."))
        }
        .confirmationDialog(
            language.localized("Prune unused volumes?"),
            isPresented: $showPruneConfirmation
        ) {
            Button(language.localized("Prune Volumes"), role: .destructive) {
                Task { await pruneVolumes() }
            }
            Button(language.localized("Cancel"), role: .cancel) {}
        } message: {
            Text(language.localized("This removes unused local volumes. Existing containers are not deleted."))
        }
        .sheet(isPresented: $showOutputSheet) {
            InspectOutputSheet(title: outputTitle, output: outputText)
        }
        .task {
            await loadVolumes()
        }
    }

    private var filteredVolumes: [String] {
        guard !searchText.isEmpty else { return volumes }
        return volumes.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var createVolumeSheet: some View {
        Form {
            Section(language.localized("Create Volume")) {
                TextField(language.localized("Volume name"), text: $newVolumeName)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) {
                    showCreateSheet = false
                    newVolumeName = ""
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Create")) {
                    createVolume(newVolumeName)
                    showCreateSheet = false
                    newVolumeName = ""
                }
                .disabled(newVolumeName.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func loadVolumes(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            volumes = try await cliBackend.listVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }

    private func createVolume(_ name: String) {
        Task {
            guard !isVolumeActionRunning else { return }
            isVolumeActionRunning = true
            defer { isVolumeActionRunning = false }
            do {
                try await cliBackend.createVolume(name: name)
                try await waitForVolume(name) { $0 }
                await loadVolumes(showLoading: false)
            } catch {
                errorMessage = error.localizedDescription
                await loadVolumes(showLoading: false)
            }
        }
    }

    private func deleteVolume(_ name: String) {
        Task {
            guard !pendingVolumes.contains(name) else { return }
            pendingVolumes.insert(name)
            defer { pendingVolumes.remove(name) }
            do {
                try await cliBackend.removeVolume(name: name)
                try await waitForVolume(name) { !$0 }
                if selectedVolume == name {
                    selectedVolume = nil
                }
                await loadVolumes(showLoading: false)
            } catch {
                errorMessage = error.localizedDescription
                await loadVolumes(showLoading: false)
            }
        }
    }

    private func inspectVolume(_ name: String) async {
        do {
            outputTitle = language.localized("Volume Inspect")
            outputText = try await cliBackend.inspectVolumes(names: [name])
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneVolumes() async {
        guard !isVolumeActionRunning else { return }
        isVolumeActionRunning = true
        defer { isVolumeActionRunning = false }
        do {
            try await cliBackend.pruneVolumes()
            await loadVolumes(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadVolumes(showLoading: false)
        }
    }

    private func waitForVolume(
        _ name: String,
        timeoutSeconds: Double = 30,
        matches: (Bool) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let latest = try await cliBackend.listVolumes()
            volumes = latest
            if matches(latest.contains(name)) {
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            fullHeaderActions
            compactHeaderActions
            minimalHeaderActions
        }
    }

    private var fullHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 110)
            newVolumeButton
            pruneButton
        }
    }

    private var compactHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 90)
            newVolumeButton
            overflowMenu
        }
    }

    private var minimalHeaderActions: some View {
        HStack(spacing: 8) {
            newVolumeButton
            overflowMenu
        }
    }

    private var newVolumeButton: some View {
        HeaderCircleButton(
            systemName: isVolumeActionRunning ? "hourglass" : "plus",
            action: { showCreateSheet = true },
            helpText: language.localized("New Volume")
        )
        .disabled(isVolumeActionRunning)
    }

    private var pruneButton: some View {
        HeaderCircleButton(
            systemName: isVolumeActionRunning ? "hourglass" : "trash",
            action: { showPruneConfirmation = true },
            helpText: language.localized("Prune volumes")
        )
        .disabled(isVolumeActionRunning)
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: language.localized("More actions")) {
            searchMenuActions
            Divider()
            Button(language.localized("Prune Volumes")) {
                showPruneConfirmation = true
            }
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(language.localized(isSearchExpanded ? "Hide Search" : "Search")) {
                isSearchExpanded.toggle()
            }

            if !searchText.isEmpty {
                Button(language.localized("Clear Search")) {
                    searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $searchText,
            isExpanded: $isSearchExpanded,
            placeholder: language.localized("Search"),
            width: width
        )
    }
}

private struct VolumeRowView: View {
    let volume: String
    let isSelected: Bool
    let isPending: Bool
    let language: AppLanguage
    let onDelete: () -> Void
    let onInspect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.18) : Color.blue.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay {
                    SwiftUI.Image(systemName: "externaldrive.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(volume)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : .primary)
                    .lineLimit(1)
            }

            Spacer()

            Group {
                if isPending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 52, alignment: .trailing)
                } else {
                    HStack(spacing: 4) {
                        Button(action: onInspect) {
                            SwiftUI.Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                        .help(language.localized("Inspect volume"))

                        Button(action: onDelete) {
                            SwiftUI.Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                        .help(language.localized("Delete volume"))
                    }
                }
            }
            .opacity(isPending || isHovered || isSelected ? 1 : 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(language.localized("Inspect")) {
                onInspect()
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text(language.localized("Delete"))
            }
        }
        .disabled(isPending)
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.listSelection)
        }
        if isHovered {
            return AnyShapeStyle(AppTheme.listHover)
        }
        return AnyShapeStyle(Color.clear)
    }
}

#Preview {
    VolumeListView(selectedVolume: .constant(nil))
}
