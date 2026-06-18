import SwiftUI

struct ContainerRowView: View {
    let container: Container
    let isSelected: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void
    let onRestart: (() -> Void)?
    let onInspect: (() -> Void)?
    let onKill: (() -> Void)?
    let onExport: (() -> Void)?
    let onCopy: (() -> Void)?

    @State private var isHovered = false

    init(
        container: Container,
        isSelected: Bool,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRestart: (() -> Void)? = nil,
        onInspect: (() -> Void)? = nil,
        onKill: (() -> Void)? = nil,
        onExport: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.container = container
        self.isSelected = isSelected
        self.onStart = onStart
        self.onStop = onStop
        self.onDelete = onDelete
        self.onRestart = onRestart
        self.onInspect = onInspect
        self.onKill = onKill
        self.onExport = onExport
        self.onCopy = onCopy
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 34, height: 34)

                SwiftUI.Image(systemName: "cube.box.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconForeground)
                
                Circle()
                    .fill(container.statusColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : .primary)
                    .lineLimit(1)
                Text(container.image)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                if container.state == .running {
                    IconButton(systemName: "link", action: {})
                    IconButton(systemName: "square.fill", action: onStop)
                        .foregroundStyle(actionColor)
                } else {
                    IconButton(systemName: "play.fill", action: onStart)
                        .foregroundStyle(actionColor)
                }
                IconButton(systemName: "trash.fill", action: onDelete)
                    .foregroundStyle(actionColor)
            }
            .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            ContainerContextMenu(
                container: container,
                onStart: onStart,
                onStop: onStop,
                onRestart: onRestart ?? {},
                onRemove: onDelete,
                onInspect: onInspect ?? {},
                onKill: onKill ?? {},
                onExport: onExport ?? {},
                onCopy: onCopy ?? {}
            )
        }
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.listSelection)
        }
        if isHovered {
            return AnyShapeStyle(AppTheme.listHover)
        }
        return AnyShapeStyle(Color.clear)
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.18) : Color.orange.opacity(0.16)
    }

    private var iconForeground: Color {
        isSelected ? .white : .orange
    }

    private var actionColor: Color {
        isSelected ? .white.opacity(0.92) : .secondary
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
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
