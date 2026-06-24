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
    @State private var pendingNetworkIDs: Set<String> = []
    @State private var isNetworkActionRunning = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let cliBackend = CLIBackend()

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: language.localized("Networks"),
                subtitle: "\(networks.count) \(language.localized("networks"))",
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
                    Text(language.localized("No networks"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNetworks.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No matching networks"))
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
                                isPending: pendingNetworkIDs.contains(network.id),
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
            Button(language.localized("Delete"), role: .destructive) {
                if let n = networkToDelete {
                    Task { await deleteNetwork(n) }
                }
                networkToDelete = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                networkToDelete = nil
            }
        } message: {
            Text(language.localized("This action cannot be undone."))
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
                Section(language.localized("Basic Settings")) {
                    TextField(language.localized("Network Name"), text: $newNetwork.name)
                    Picker(language.localized("Driver"), selection: $newNetwork.driver) {
                        Text("bridge").tag("bridge")
                        Text("host").tag("host")
                        Text("none").tag("none")
                    }
                }

                Section(language.localized("IPAM Configuration")) {
                    TextField(language.localized("Subnet (e.g., 172.20.0.0/16)"), text: $newNetwork.subnet)
                    TextField(language.localized("Gateway (e.g., 172.20.0.1)"), text: $newNetwork.gateway)
                }

                Section(language.localized("Options")) {
                    Toggle(language.localized("Internal network"), isOn: $newNetwork.isInternal)
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 350)
            .navigationTitle(language.localized("Create Network"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.localized("Cancel")) {
                        showCreateSheet = false
                        newNetwork = NetworkConfig()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("Create")) {
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

    private func loadNetworks(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            networks = try await cliBackend.listNetworks()
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }

    private func createNetwork(_ config: NetworkConfig) async {
        guard !isNetworkActionRunning else { return }
        isNetworkActionRunning = true
        defer { isNetworkActionRunning = false }
        do {
            try await cliBackend.createNetwork(config: config)
            try await waitForNetwork(id: config.name) { $0 != nil }
            await loadNetworks(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadNetworks(showLoading: false)
        }
    }

    private func deleteNetwork(_ network: Network) async {
        guard !pendingNetworkIDs.contains(network.id) else { return }
        pendingNetworkIDs.insert(network.id)
        defer { pendingNetworkIDs.remove(network.id) }
        do {
            try await cliBackend.removeNetwork(id: network.id)
            try await waitForNetwork(id: network.id) { $0 == nil }
            if selectedNetwork?.id == network.id {
                selectedNetwork = nil
            }
            await loadNetworks(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadNetworks(showLoading: false)
        }
    }

    private func inspectNetwork(_ network: Network) async {
        do {
            outputTitle = language.localized("Network Inspect")
            outputText = try await cliBackend.inspectNetworks(ids: [network.id])
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pruneNetworks() async {
        guard !isNetworkActionRunning else { return }
        isNetworkActionRunning = true
        defer { isNetworkActionRunning = false }
        do {
            try await cliBackend.pruneNetworks()
            await loadNetworks(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadNetworks(showLoading: false)
        }
    }

    private func waitForNetwork(
        id: String,
        timeoutSeconds: Double = 30,
        matches: (Network?) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let latest = try await cliBackend.listNetworks()
            networks = latest
            if matches(latest.first(where: { $0.id == id || $0.name == id })) {
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
            systemName: isNetworkActionRunning ? "hourglass" : "plus",
            action: { showCreateSheet = true },
            helpText: language.localized("New Network")
        )
        .disabled(isNetworkActionRunning)
    }

    private var pruneButton: some View {
        HeaderCircleButton(
            systemName: isNetworkActionRunning ? "hourglass" : "trash",
            action: { Task { await pruneNetworks() } },
            helpText: language.localized("Prune networks")
        )
        .disabled(isNetworkActionRunning)
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: language.localized("More actions")) {
            searchMenuActions
            Divider()
            Button(language.localized("Prune Networks")) {
                Task { await pruneNetworks() }
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

#Preview {
    NetworkListView(selectedNetwork: .constant(nil))
}
