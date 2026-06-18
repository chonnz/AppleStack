import SwiftUI

struct NetworkListView: View {
    @Binding var selectedNetwork: Network?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var networks: [Network] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newNetwork = NetworkConfig()
    @State private var outputTitle = ""
    @State private var outputText = ""
    @State private var showOutputSheet = false
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var networkToDelete: Network?

    private let cliBackend = CLIBackend()

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: "Networks",
                subtitle: "\(networks.count) networks",
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
                        Task { await loadNetworks() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if networks.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "network")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text("No networks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNetworks.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No matching networks")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredNetworks) { network in
                            NetworkRowView(
                                network: network,
                                isSelected: selectedNetwork?.id == network.id,
                                onDelete: { networkToDelete = network },
                                onInspect: { Task { await inspectNetwork(network) } }
                            )
                            .onTapGesture {
                                selectedNetwork = network
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
            createNetworkSheet
        }
        .confirmationDialog(
            "Delete network \"\(networkToDelete?.name ?? "")\"?",
            isPresented: .init(
                get: { networkToDelete != nil },
                set: { if !$0 { networkToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let n = networkToDelete {
                    Task { await deleteNetwork(n) }
                }
                networkToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                networkToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showOutputSheet) {
            InspectOutputSheet(title: outputTitle, output: outputText)
        }
        .task {
            await loadNetworks()
        }
    }

    private var filteredNetworks: [Network] {
        guard !searchText.isEmpty else { return networks }
        return networks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.driver.localizedCaseInsensitiveContains(searchText) ||
            $0.scope.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var createNetworkSheet: some View {
        NavigationStack {
            Form {
                Section("Basic Settings") {
                    TextField("Network Name", text: $newNetwork.name)
                    Picker("Driver", selection: $newNetwork.driver) {
                        Text("bridge").tag("bridge")
                        Text("host").tag("host")
                        Text("none").tag("none")
                    }
                }

                Section("IPAM Configuration") {
                    TextField("Subnet (e.g., 172.20.0.0/16)", text: $newNetwork.subnet)
                    TextField("Gateway (e.g., 172.20.0.1)", text: $newNetwork.gateway)
                }

                Section("Options") {
                    Toggle("Internal network", isOn: $newNetwork.isInternal)
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 350)
            .navigationTitle("Create Network")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateSheet = false
                        newNetwork = NetworkConfig()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createNetwork(newNetwork)
                            showCreateSheet = false
                            newNetwork = NetworkConfig()
                        }
                    }
                    .disabled(newNetwork.name.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadNetworks() async {
        isLoading = true
        errorMessage = nil
        do {
            networks = try await cliBackend.listNetworks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createNetwork(_ config: NetworkConfig) async {
        do {
            try await cliBackend.createNetwork(config: config)
            await loadNetworks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNetwork(_ network: Network) async {
        do {
            try await cliBackend.removeNetwork(id: network.id)
            if selectedNetwork?.id == network.id {
                selectedNetwork = nil
            }
            await loadNetworks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func inspectNetwork(_ network: Network) async {
        do {
            outputTitle = "Network Inspect"
            outputText = try await cliBackend.inspectNetworks(ids: [network.id])
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneNetworks() async {
        do {
            try await cliBackend.pruneNetworks()
            await loadNetworks()
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
            newNetworkButton
            pruneButton
        }
    }

    private var compactHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 88)
            newNetworkButton
            overflowMenu
        }
    }

    private var minimalHeaderActions: some View {
        HStack(spacing: 8) {
            newNetworkButton
            overflowMenu
        }
    }

    private var newNetworkButton: some View {
        HeaderCircleButton(
            systemName: "plus",
            action: { showCreateSheet = true },
            helpText: "New Network"
        )
    }

    private var pruneButton: some View {
        HeaderCircleButton(
            systemName: "trash",
            action: { Task { await pruneNetworks() } },
            helpText: "Prune networks"
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: "More actions") {
            searchMenuActions
            Divider()
            Button("Prune Networks") {
                Task { await pruneNetworks() }
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

#Preview {
    NetworkListView(selectedNetwork: .constant(nil))
}
