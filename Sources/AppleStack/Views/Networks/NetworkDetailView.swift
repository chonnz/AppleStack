import SwiftUI

struct NetworkDetailView: View {
    let network: Network

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                Text("Info")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(label: "Name", value: network.name)
                        InfoRow(label: "ID", value: network.id)
                        InfoRow(label: "Driver", value: network.driver)
                        InfoRow(label: "Scope", value: network.scope)
                        InfoRow(label: "IPAM Driver", value: network.ipamDriver)
                        InfoRow(label: "Containers", value: "\(network.containers)")
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if !network.subnet.isEmpty || !network.gateway.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IP Configuration")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 0) {
                                if !network.subnet.isEmpty {
                                    InfoRow(label: "Subnet", value: network.subnet)
                                }
                                if !network.gateway.isEmpty {
                                    InfoRow(label: "Gateway", value: network.gateway)
                                }
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
        .background(.white)
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
    ))
}
