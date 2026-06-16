import SwiftUI

struct NetworkListView: View {
    @State private var networks: [Network] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newNetwork = NetworkConfig()
    @State private var selectedNetwork: Network?

    private let cliBackend = CLIBackend()

    var body: some View {
        HStack(spacing: 0) {
            // Network list
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Networks")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(networks.count) networks")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showCreateSheet = true
                    } label: {
                        SwiftUI.Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

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
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No networks")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    networkList
                }
            }
            .frame(minWidth: 280, idealWidth: 320)

            Divider()

            // Network detail
            if let network = selectedNetwork {
                NetworkDetailView(network: network)
            } else {
                VStack {
                    Spacer()
                    Text("No Selection")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showCreateSheet) {
            createNetworkSheet
        }
        .task {
            await loadNetworks()
        }
    }

    private var networkList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(networks) { network in
                    NetworkRowView(
                        network: network,
                        isSelected: selectedNetwork?.id == network.id,
                        onDelete: { Task { await deleteNetwork(network) } }
                    )
                    .onTapGesture {
                        selectedNetwork = network
                    }

                    Divider()
                        .padding(.leading, 48)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var createNetworkSheet: some View {
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
}

#Preview {
    NetworkListView()
}
