import SwiftUI

struct ImageRowView: View {
    let image: Image
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(image.repository)
                        .font(.headline)
                    Text(":\(image.tag)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(image.sizeFormatted, systemImage: "internaldrive")
                    Label(image.created, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                SwiftUI.Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete image")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ImageRowView(
        image: Image(
            id: "1",
            repository: "nginx",
            tag: "latest",
            size: 142_000_000,
            created: "2 weeks ago"
        ),
        onDelete: {}
    )
}
