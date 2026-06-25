import SwiftUI

struct ContainerListView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selectedContainer: Container?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var isSearchExpanded = false
    @State private var containerToDelete: Container?
    @State private var containerToKill: Container?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: language.localized("Containers"),
                subtitle: "\(viewModel.containers.filter { $0.state == .running }.count) \(language.localized("running"))",
                leadingAccessory: nil,
                leadingInset: showsSidebarToggle ? AppTheme.windowControlsClearance : 0
            ) {
                headerActions
            }

            if viewModel.isLoading && viewModel.containers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredContainers.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "cube.box")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No containers"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.filteredContainers) { container in
                            ContainerRowView(
                                container: container,
                                isSelected: selectedContainer?.id == container.id,
                                isPending: viewModel.isPending(container),
                                onStart: { Task { await viewModel.start(container) } },
                                onStop: { Task { await viewModel.stop(container) } },
                                onDelete: { containerToDelete = container },
                                onRestart: {
                                    Task {
                                        await viewModel.stop(container)
                                        await viewModel.start(container)
                                    }
                                },
                                onInspect: { Task { await viewModel.inspect(container) } },
                                onKill: { containerToKill = container },
                                onExport: { export(container) },
                                onCopy: {
                                    viewModel.copySource = "\(container.id):/"
                                    viewModel.copyDestination = ""
                                    viewModel.showCopySheet = true
                                }
                            )
                            .onTapGesture {
                                selectedContainer = container
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateContainerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showInspectSheet) {
            InspectOutputSheet(title: language.localized("Container Inspect"), output: viewModel.inspectOutput)
        }
        .sheet(isPresented: $viewModel.showCopySheet) {
            CopyPathSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button(language.localized("OK")) {
                viewModel.showError = false
            }
            if viewModel.errorMessage != nil {
                Button(language.localized("Retry")) {
                    viewModel.showError = false
                    Task { await viewModel.loadContainers() }
                }
                Button(language.localized("Start System")) {
                    viewModel.showError = false
                    Task {
                        try? await CLIBackend().systemStart()
                        await viewModel.loadContainers()
                    }
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .confirmationDialog(
            "Delete container \"\(containerToDelete?.name ?? "")\"?",
            isPresented: .init(
                get: { containerToDelete != nil },
                set: { if !$0 { containerToDelete = nil } }
            )
        ) {
            Button(language.localized("Delete"), role: .destructive) {
                if let c = containerToDelete {
                    Task { await viewModel.delete(c) }
                }
                containerToDelete = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                containerToDelete = nil
            }
        } message: {
            Text(language.localized("This action cannot be undone."))
        }
        .confirmationDialog(
            language.localized("Kill container?"),
            isPresented: .init(
                get: { containerToKill != nil },
                set: { if !$0 { containerToKill = nil } }
            )
        ) {
            Button(language.localized("Kill"), role: .destructive) {
                if let c = containerToKill {
                    Task { await viewModel.kill(c) }
                }
                containerToKill = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                containerToKill = nil
            }
        } message: {
            Text(language.localized("This immediately stops the running process inside the container."))
        }
        .task {
            await viewModel.loadContainers()
            selectFirstVisibleContainerIfNeeded()
            viewModel.startAutoRefresh()
        }
        .onChange(of: viewModel.filteredContainers.map(\.id)) { _, _ in
            selectFirstVisibleContainerIfNeeded()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .background {
            Button("") { viewModel.showCreateSheet = true }
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
            Button("") { Task { await viewModel.loadContainers() } }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()
        }
    }

    private func export(_ container: Container) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(container.name).tar"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.export(container, to: url.path) }
        }
    }

    private func selectFirstVisibleContainerIfNeeded() {
        let visibleContainers = viewModel.filteredContainers
        guard !visibleContainers.isEmpty else {
            selectedContainer = nil
            return
        }

        if let selectedContainer,
           visibleContainers.contains(where: { $0.id == selectedContainer.id }) {
            return
        }

        selectedContainer = visibleContainers[0]
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
            searchToggle(width: 120)
            createContainerButton
        }
    }

    private var compactHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 92)
            createContainerButton
        }
    }

    private var minimalHeaderActions: some View {
        HStack(spacing: 8) {
            createContainerButton
            overflowMenu
        }
    }

    private var createContainerButton: some View {
        HeaderCircleButton(
            systemName: "plus",
            action: { viewModel.showCreateSheet = true },
            helpText: language.localized("New Container")
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: language.localized("More actions")) {
            searchMenuActions
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(isSearchExpanded ? language.localized("Hide Search") : language.localized("Search")) {
                isSearchExpanded.toggle()
            }

            if !viewModel.searchText.isEmpty {
                Button(language.localized("Clear Search")) {
                    viewModel.searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $viewModel.searchText,
            isExpanded: $isSearchExpanded,
            placeholder: language.localized("Search"),
            width: width
        )
    }
}

private struct CopyPathSheet: View {
    @Bindable var viewModel: ContainerListViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Copy Files")) {
                TextField(language.localized("Source (container:path or local path)"), text: $viewModel.copySource)
                TextField(language.localized("Destination (container:path or local path)"), text: $viewModel.copyDestination)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 180)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Copy")) {
                    Task { await viewModel.copyPath() }
                }
                .disabled(viewModel.copySource.isEmpty || viewModel.copyDestination.isEmpty)
            }
        }
    }
}

#Preview {
    ContainerListView(
        viewModel: ContainerListViewModel(service: ContainerServiceFactory.create()),
        selectedContainer: .constant(nil)
    )
}
