import SwiftUI

struct VolumeDetailView: View {
    let volumeName: String
    let selectedTab: String

    @State private var details: VolumeInspectionDetails?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var rawInspectOutput: String?

    private let cliBackend = CLIBackend()

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
                                InspectorSection(title: "Labels") {
                                    InspectorCard {
                                        InspectorKeyValueTable(items: details.labels)
                                    }
                                }
                            }
                        case "Options":
                            if !details.options.isEmpty {
                                InspectorSection(title: "Options") {
                                    InspectorCard {
                                        InspectorKeyValueTable(items: details.options)
                                    }
                                }
                            }
                        case "Inspect":
                            InspectorSection(title: "Inspect") {
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

                            if !details.storageRows.isEmpty {
                                InspectorSection(title: "Storage") {
                                    InspectorCard {
                                        InspectorRows(rows: details.storageRows)
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
                    Button("Retry") {
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
        .task(id: volumeName) {
            await loadDetails()
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            let output = try await cliBackend.inspectVolumes(names: [volumeName])
            rawInspectOutput = output
            details = try VolumeInspectionDetails.parse(from: output, fallbackName: volumeName)
        } catch {
            details = VolumeInspectionDetails.fallback(name: volumeName)
            rawInspectOutput = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct VolumeInspectionDetails {
    let overviewRows: [InspectorDataRow]
    let storageRows: [InspectorDataRow]
    let labels: [InspectorKeyValueItem]
    let options: [InspectorKeyValueItem]

    static func fallback(name: String) -> VolumeInspectionDetails {
        VolumeInspectionDetails(
            overviewRows: [.init(label: "Name", value: name)],
            storageRows: [],
            labels: [],
            options: []
        )
    }

    static func parse(from output: String, fallbackName: String) throws -> VolumeInspectionDetails {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let root = array.first
        else {
            throw CommandError.invalidOutput
        }

        let configuration = root["configuration"] as? [String: Any]
        let labels = configuration?["labels"] as? [String: Any] ?? [:]
        let options = configuration?["options"] as? [String: Any] ?? [:]

        let overviewRows = [
            InspectorDataRow(label: "Name", value: configuration?["name"] as? String ?? root["id"] as? String ?? fallbackName),
            InspectorDataRow(label: "ID", value: root["id"] as? String ?? fallbackName, usesMonospacedFont: true),
            InspectorDataRow(label: "Driver", value: configuration?["driver"] as? String ?? ""),
            InspectorDataRow(label: "Format", value: configuration?["format"] as? String ?? ""),
            InspectorDataRow(label: "Created", value: inspectorFormatTimestamp(configuration?["creationDate"] as? String ?? "")),
        ].filter(\.hasContent)

        let storageRows = [
            InspectorDataRow(label: "Size", value: inspectorFormatBytes(configuration?["sizeInBytes"]) ?? ""),
            InspectorDataRow(label: "Source", value: configuration?["source"] as? String ?? "", usesMonospacedFont: true),
        ].filter(\.hasContent)

        let labelItems = labels.keys.sorted().map {
            InspectorKeyValueItem(key: $0, value: "\(labels[$0] ?? "")")
        }
        let optionItems = options.keys.sorted().map {
            InspectorKeyValueItem(key: $0, value: "\(options[$0] ?? "")")
        }

        return VolumeInspectionDetails(
            overviewRows: overviewRows,
            storageRows: storageRows,
            labels: labelItems,
            options: optionItems
        )
    }
}
