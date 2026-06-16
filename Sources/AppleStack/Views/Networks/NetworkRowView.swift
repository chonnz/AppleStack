import SwiftUI

struct NetworkRowView: View {
    let network: Network
    let isSelected: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Network icon
            SwiftUI.Image(systemName: "network")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .padding(.leading, 8)

            // Name and driver
            VStack(alignment: .leading, spacing: 2) {
                Text(network.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(network.driver)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Container count
            Text("\(network.containers) containers")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Delete button
            Button(action: onDelete) {
                SwiftUI.Image(systemName: "trash")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Delete network")
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
    }
}

#Preview {
    NetworkRowView(
        network: Network(
            id: "abc123",
            name: "my-network",
            driver: "bridge",
            containers: 3
        ),
        isSelected: false,
        onDelete: {}
    )
}
