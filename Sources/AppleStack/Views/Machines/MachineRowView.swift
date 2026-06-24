import SwiftUI

struct MachineRowView: View {
    let machine: Machine
    let isSelected: Bool
    let isPending: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.secondary.opacity(0.10))

                SwiftUI.Image(systemName: "desktopcomputer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 3, y: 3)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(machine.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : .primary)
                    .lineLimit(1)
                Text(machine.status.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : statusColor)
            }

            Spacer()

            Group {
                if isPending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 52, alignment: .trailing)
                } else {
                    HStack(spacing: 4) {
                        if machine.status == .running {
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
            }
            .disabled(isPending)
            .opacity(isPending || isHovered || isSelected ? 1 : 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isPending)
    }

    private var statusColor: Color {
        switch machine.status {
        case .running: return .green
        case .stopped: return .gray
        case .creating: return .orange
        case .error: return .red
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
    MachineRowView(
        machine: Machine(
            id: "abc123",
            name: "my-machine",
            status: .running,
            cpus: 2,
            memory: "2g"
        ),
        isSelected: false,
        isPending: false,
        onStart: {},
        onStop: {},
        onDelete: {}
    )
}
