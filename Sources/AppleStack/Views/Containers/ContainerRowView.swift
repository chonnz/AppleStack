import SwiftUI

struct ContainerRowView: View {
    let container: Container
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .font(.headline)
                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label(container.ports.isEmpty ? "No ports" : container.ports,
                          systemImage: "network")
                    Label(container.memory, systemImage: "memorychip")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(text: container.state.rawValue.capitalized,
                       color: container.statusColor)

            HStack(spacing: 8) {
                if container.state == .running {
                    Button {
                        onStop()
                    } label: {
                        SwiftUI.Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Stop container")
                } else {
                    Button {
                        onStart()
                    } label: {
                        SwiftUI.Image(systemName: "play.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Start container")
                }

                Button {
                    onDelete()
                } label: {
                    SwiftUI.Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete container")
            }
        }
        .padding(.vertical, 4)
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
        onStart: {},
        onStop: {},
        onDelete: {}
    )
}
