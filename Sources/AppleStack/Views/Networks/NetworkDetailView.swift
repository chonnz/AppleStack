import SwiftUI

struct NetworkDetailView: View {
    let network: Network
    let selectedTab: String

    @State private var details: NetworkInspectionDetails?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var rawInspectOutput: String?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let cliBackend = CLIBackend()

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Group {
            if isLoading && details == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case "Labels":
                            if !details.labels.isEmpty {
                                InspectorSection(title: language.localized("Labels")) {
                                    InspectorCard {
                                        InspectorKeyValueTable(items: details.labels)
                                    }
                                }
                            }
                        case "Options":
                            if !details.options.isEmpty {
                                InspectorSection(title: language.localized("Options")) {
                                    InspectorCard {
                                        InspectorKeyValueTable(items: details.options)
                                    }
                                }
                            }
                        case "Inspect":
                            InspectorSection(title: language.localized("Inspect")) {
                                InspectorCard {
                                    Text(rawInspectOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? rawInspectOutput! : "No inspect output available")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        default:
                            InspectorSection(title: "Overview") {
                                InspectorCard {
                                    InspectorRows(rows: details.overviewRows)
                                }
                            }

                            if !details.addressRows.isEmpty {
                                InspectorSection(title: "Addressing") {
                                    InspectorCard {
                                        InspectorRows(rows: details.addressRows)
                                    }
                                }
                            }

                            if !details.usedBy.isEmpty {
                                InspectorSection(title: "Used By") {
                                    InspectorCard {
                                        InspectorTagFlow(items: details.usedBy)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(language.localized("Retry")) {
                        Task { await loadDetails() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                Color.clear
            }
        }
        .background(AppTheme.paneBackground)
        .task(id: network.id) {
            await loadDetails()
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            let output = try await cliBackend.inspectNetworks(ids: [network.id])
            rawInspectOutput = output
            details = try NetworkInspectionDetails.parse(from: output, fallback: network)
        } catch {
            details = NetworkInspectionDetails.fallback(from: network)
            rawInspectOutput = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct NetworkInspectionDetails {
    let overviewRows: [InspectorDataRow]
    let addressRows: [InspectorDataRow]
    let usedBy: [String]
    let labels: [InspectorKeyValueItem]
    let options: [InspectorKeyValueItem]

    static func fallback(from network: Network) -> NetworkInspectionDetails {
        NetworkInspectionDetails(
            overviewRows: [
                .init(label: "Name", value: network.name),
                .init(label: "ID", value: network.id, usesMonospacedFont: true),
                .init(label: "Driver", value: network.driver),
                .init(label: "Scope", value: network.scope),
                .init(label: "IPAM Driver", value: network.ipamDriver),
            ].filter(\.hasContent),
            addressRows: [
                .init(label: "IPv4 Subnet", value: network.subnet),
                .init(label: "IPv4 Gateway", value: network.gateway),
            ].filter(\.hasContent),
            usedBy: network.containers > 0 ? ["\(network.containers) attached containers"] : [],
            labels: [],
            options: []
        )
    }

    static func parse(from output: String, fallback network: Network) throws -> NetworkInspectionDetails {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let root = array.first
        else {
            throw CommandError.invalidOutput
        }

        let configuration = root["configuration"] as? [String: Any]
        let status = root["status"] as? [String: Any]
        let labels = configuration?["labels"] as? [String: Any] ?? [:]
        let options = configuration?["options"] as? [String: Any] ?? [:]
        let usedBy = parseUsedBy(status: status, fallbackCount: network.containers)

        let overviewRows = [
            InspectorDataRow(label: "Name", value: configuration?["name"] as? String ?? network.name),
            InspectorDataRow(label: "ID", value: root["id"] as? String ?? network.id, usesMonospacedFont: true),
            InspectorDataRow(label: "Driver", value: configuration?["plugin"] as? String ?? network.driver),
            InspectorDataRow(label: "Mode", value: configuration?["mode"] as? String ?? ""),
            InspectorDataRow(label: "Scope", value: network.scope),
            InspectorDataRow(label: "Created", value: inspectorFormatTimestamp(configuration?["creationDate"] as? String ?? "")),
        ].filter(\.hasContent)

        let addressRows = [
            InspectorDataRow(label: "IPv4 Subnet", value: status?["ipv4Subnet"] as? String ?? network.subnet),
            InspectorDataRow(label: "IPv4 Gateway", value: status?["ipv4Gateway"] as? String ?? network.gateway),
            InspectorDataRow(label: "IPv6 Subnet", value: status?["ipv6Subnet"] as? String ?? ""),
        ].filter(\.hasContent)

        let labelItems = labels.keys.sorted().map {
            InspectorKeyValueItem(key: $0, value: "\(labels[$0] ?? "")")
        }
        let optionItems = options.keys.sorted().map {
            InspectorKeyValueItem(key: $0, value: "\(options[$0] ?? "")")
        }

        return NetworkInspectionDetails(
            overviewRows: overviewRows,
            addressRows: addressRows,
            usedBy: usedBy,
            labels: labelItems,
            options: optionItems
        )
    }

    private static func parseUsedBy(status: [String: Any]?, fallbackCount: Int) -> [String] {
        guard let status else {
            return fallbackCount > 0 ? ["\(fallbackCount) attached containers"] : []
        }

        if let members = status["containers"] as? [String] {
            return members
        }

        if let members = status["containers"] as? [[String: Any]] {
            let names = members.compactMap { member in
                member["name"] as? String ?? member["id"] as? String
            }
            if !names.isEmpty {
                return names
            }
        }

        if let members = status["containers"] as? [String: Any] {
            let names = members.keys.sorted()
            if !names.isEmpty {
                return names
            }
        }

        return fallbackCount > 0 ? ["\(fallbackCount) attached containers"] : []
    }
}

#Preview {
    NetworkDetailView(network: Network(
        id: "abc123",
        name: "my-network",
        driver: "bridge",
        subnet: "172.20.0.0/16",
        gateway: "172.20.0.1",
        containers: 3
    ), selectedTab: "Info")
}
