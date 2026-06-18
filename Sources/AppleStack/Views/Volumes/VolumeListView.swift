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

    private let cliBackend = CLIBackend()

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: "Volumes",
                subtitle: "\(volumes.count) volumes",
                leadingAccessory: nil,
                leadingInset: 0
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
                    Button("Retry") {
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
                    Text("No volumes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredVolumes.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No matching volumes")
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
                                onDelete: { deleteVolume(volume) },
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
            Section("Create Volume") {
                TextField("Volume name", text: $newVolumeName)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showCreateSheet = false
                    newVolumeName = ""
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createVolume(newVolumeName)
                    showCreateSheet = false
                    newVolumeName = ""
                }
                .disabled(newVolumeName.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func loadVolumes() async {
        isLoading = true
        errorMessage = nil
        do {
            volumes = try await cliBackend.listVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createVolume(_ name: String) {
        Task {
            do {
                try await cliBackend.createVolume(name: name)
                await loadVolumes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteVolume(_ name: String) {
        Task {
            do {
                try await cliBackend.removeVolume(name: name)
                await loadVolumes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func inspectVolume(_ name: String) async {
        do {
            outputTitle = "Volume Inspect"
            outputText = try await cliBackend.inspectVolumes(names: [name])
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneVolumes() async {
        do {
            try await cliBackend.pruneVolumes()
            await loadVolumes()
        } catch {
            errorMessage = error.localizedDescription
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
            systemName: "plus",
            action: { showCreateSheet = true },
            helpText: "New Volume"
        )
    }

    private var pruneButton: some View {
        HeaderCircleButton(
            systemName: "trash",
            action: { Task { await pruneVolumes() } },
            helpText: "Prune volumes"
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: "More actions") {
            searchMenuActions
            Divider()
            Button("Prune Volumes") {
                Task { await pruneVolumes() }
            }
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(isSearchExpanded ? "Hide Search" : "Search") {
                isSearchExpanded.toggle()
            }

            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $searchText,
            isExpanded: $isSearchExpanded,
            placeholder: "Search",
            width: width
        )
    }
}

private struct VolumeRowView: View {
    let volume: String
    let isSelected: Bool
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

            HStack(spacing: 4) {
                Button(action: onInspect) {
                    SwiftUI.Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                .help("Inspect volume")

                Button(action: onDelete) {
                    SwiftUI.Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                .help("Delete volume")
            }
            .opacity(isHovered || isSelected ? 1 : 0)
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
            Button("Inspect") {
                onInspect()
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text("Delete")
            }
        }
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
