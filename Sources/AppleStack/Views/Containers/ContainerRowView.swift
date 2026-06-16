import SwiftUI

struct ContainerRowView: View {
    let container: Container
    let isSelected: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void
    let onRestart: (() -> Void)?
    let onInspect: (() -> Void)?

    init(
        container: Container,
        isSelected: Bool,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRestart: (() -> Void)? = nil,
        onInspect: (() -> Void)? = nil
    ) {
        self.container = container
        self.isSelected = isSelected
        self.onStart = onStart
        self.onStop = onStop
        self.onDelete = onDelete
        self.onRestart = onRestart
        self.onInspect = onInspect
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(container.statusColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 8)

            // Container icon
            SwiftUI.Image(systemName: "shippingbox.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            // Name and image
            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(container.image)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 4) {
                if container.state == .running {
                    IconButton(systemName: "link", action: {}, tooltip: "Ports")
                    IconButton(systemName: "stop.fill", action: onStop, tooltip: "Stop")
                        .foregroundStyle(.red)
                } else {
                    IconButton(systemName: "play.fill", action: onStart, tooltip: "Start")
                        .foregroundStyle(.green)
                }
                IconButton(systemName: "trash", action: onDelete, tooltip: "Delete")
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
        .contextMenu {
            ContainerContextMenu(
                container: container,
                onStart: onStart,
                onStop: onStop,
                onRestart: onRestart ?? {},
                onRemove: onDelete,
                onInspect: onInspect ?? {}
            )
        }
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var tooltip: String = ""

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 12))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

#Preview {
    ContainerRowView(
        container: Container(
            id: "1",
            name: "my-app",
            image: "nginx:latest",
            status: .running,
            state: .running,
            created: "2 hours ago",
            ports: "8080:80",
            cpus: 2,
            memory: "512m"
        ),
        isSelected: true,
        onStart: {},
        onStop: {},
        onDelete: {}
    )
}
