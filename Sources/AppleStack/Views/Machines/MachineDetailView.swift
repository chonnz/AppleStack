import SwiftUI

struct MachineDetailView: View {
    let machine: Machine
    @State private var selectedTab = 0

    private let tabs = ["Info", "Terminal"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        selectedTab = index
                    } label: {
                        Text(tab)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedTab == index ? .black : .secondary)
                            .background(selectedTab == index ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white)

            Divider()

            // Tab content
            switch selectedTab {
            case 0:
                infoView
            case 1:
                terminalView
            default:
                infoView
            }
        }
        .background(.white)
    }

    // MARK: - Info Tab

    private var infoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    InfoRow(label: "Name", value: machine.name)
                    InfoRow(label: "ID", value: machine.id)
                    InfoRow(label: "Status", value: machine.status.rawValue)
                    InfoRow(label: "Image", value: machine.image)
                    InfoRow(label: "Created", value: machine.created)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Resources")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(label: "CPUs", value: "\(machine.cpus)")
                        InfoRow(label: "Memory", value: machine.memory)
                        InfoRow(label: "Disk", value: machine.disk)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if !machine.ip.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Network")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 0) {
                            InfoRow(label: "IP Address", value: machine.ip)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Terminal Tab

    private var terminalView: some View {
        VStack(spacing: 0) {
            if machine.status != .running {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Machine is not running")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Start the machine to access the terminal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Terminal output
                    ScrollView([.horizontal, .vertical]) {
                        Text("Terminal session for \(machine.name)\n\n$ ")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(Color(nsColor: .textBackgroundColor))

                    Divider()

                    // Command input
                    HStack(spacing: 8) {
                        Text("$")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)

                        TextField("Enter command...", text: .constant(""))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
    }
}

#Preview {
    MachineDetailView(machine: Machine(
        id: "abc123",
        name: "my-machine",
        status: .running,
        image: "ubuntu:latest",
        cpus: 2,
        memory: "2g",
        disk: "20g",
        ip: "192.168.64.2"
    ))
}
