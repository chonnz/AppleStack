import SwiftUI

struct ImageRowView: View {
    let image: Image
    let isSelected: Bool
    let onDelete: () -> Void
    let onPull: (() -> Void)?
    let onInspect: (() -> Void)?

    init(
        image: Image,
        isSelected: Bool,
        onDelete: @escaping () -> Void,
        onPull: (() -> Void)? = nil,
        onInspect: (() -> Void)? = nil
    ) {
        self.image = image
        self.isSelected = isSelected
        self.onDelete = onDelete
        self.onPull = onPull
        self.onInspect = onInspect
    }

    var body: some View {
        HStack(spacing: 12) {
            // Image icon
            SwiftUI.Image(systemName: "photo.stack.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .padding(.leading, 8)

            // Repository and tag
            VStack(alignment: .leading, spacing: 2) {
                Text(image.repository)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(image.tag)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(image.sizeFormatted)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Delete button
            Button(action: onDelete) {
                SwiftUI.Image(systemName: "trash")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Delete image")
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
        .contextMenu {
            ImageContextMenu(
                image: image,
                onPull: onPull ?? {},
                onRemove: onDelete,
                onInspect: onInspect ?? {}
            )
        }
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
        isSelected: false,
        onDelete: {}
    )
}
