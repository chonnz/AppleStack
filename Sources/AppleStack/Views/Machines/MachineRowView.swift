import SwiftUI

struct MachineRowView: View {
    let machine: Machine
    let isSelected: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 8)

            // Machine icon
            SwiftUI.Image(systemName: "desktopcomputer")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(machine.status.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 4) {
                if machine.status == .running {
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
    }

    private var statusColor: Color {
        switch machine.status {
        case .running: return .green
        case .stopped: return .gray
        case .creating: return .orange
        case .error: return .red
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
    MachineRowView(
        machine: Machine(
            id: "abc123",
            name: "my-machine",
            status: .running,
            cpus: 2,
            memory: "2g"
        ),
        isSelected: false,
        onStart: {},
        onStop: {},
        onDelete: {}
    )
}
