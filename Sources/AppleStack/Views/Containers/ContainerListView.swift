import SwiftUI

struct ContainerListView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selectedContainer: Container?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var isSearchExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: "Containers",
                subtitle: "\(viewModel.containers.filter { $0.state == .running }.count) running",
                leadingAccessory: nil,
                leadingInset: 0
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
                    Text("No containers")
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
                                onStart: { Task { await viewModel.start(container) } },
                                onStop: { Task { await viewModel.stop(container) } },
                                onDelete: { Task { await viewModel.delete(container) } },
                                onRestart: {
                                    Task {
                                        await viewModel.stop(container)
                                        await viewModel.start(container)
                                    }
                                },
                                onInspect: { Task { await viewModel.inspect(container) } },
                                onKill: { Task { await viewModel.kill(container) } },
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
            InspectOutputSheet(title: "Container Inspect", output: viewModel.inspectOutput)
        }
        .sheet(isPresented: $viewModel.showCopySheet) {
            CopyPathSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button("OK") {
                viewModel.showError = false
            }
            if viewModel.errorMessage != nil {
                Button("Retry") {
                    viewModel.showError = false
                    Task { await viewModel.loadContainers() }
                }
                Button("Start System") {
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
        .task {
            await viewModel.loadContainers()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private func export(_ container: Container) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(container.name).tar"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.export(container, to: url.path) }
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
            helpText: "New Container"
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: "More actions") {
            searchMenuActions
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(isSearchExpanded ? "Hide Search" : "Search") {
                isSearchExpanded.toggle()
            }

            if !viewModel.searchText.isEmpty {
                Button("Clear Search") {
                    viewModel.searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $viewModel.searchText,
            isExpanded: $isSearchExpanded,
            placeholder: "Search",
            width: width
        )
    }
}

private struct CopyPathSheet: View {
    @Bindable var viewModel: ContainerListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Copy Files") {
                TextField("Source (container:path or local path)", text: $viewModel.copySource)
                TextField("Destination (container:path or local path)", text: $viewModel.copyDestination)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 180)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Copy") {
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
