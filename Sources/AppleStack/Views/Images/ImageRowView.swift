import SwiftUI

struct ImageRowView: View {
    let image: Image
    let isSelected: Bool
    let isPending: Bool
    let usageSummary: String?
    let isDangling: Bool
    let onDelete: () -> Void
    let onPull: (() -> Void)?
    let onInspect: (() -> Void)?
    let onTag: (() -> Void)?
    let onPush: (() -> Void)?
    let onSave: (() -> Void)?

    @State private var isHovered = false

    init(
        image: Image,
        isSelected: Bool = false,
        isPending: Bool = false,
        usageSummary: String? = nil,
        isDangling: Bool = false,
        onDelete: @escaping () -> Void,
        onPull: (() -> Void)? = nil,
        onInspect: (() -> Void)? = nil,
        onTag: (() -> Void)? = nil,
        onPush: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.image = image
        self.isSelected = isSelected
        self.isPending = isPending
        self.usageSummary = usageSummary
        self.isDangling = isDangling
        self.onDelete = onDelete
        self.onPull = onPull
        self.onInspect = onInspect
        self.onTag = onTag
        self.onPush = onPush
        self.onSave = onSave
    }

    var body: some View {
        HStack(spacing: 12) {
            imageBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(image.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : .primary)
                    .lineLimit(1)

                Text(metadataText)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Group {
                if isPending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                } else {
                    HStack(spacing: 4) {
                        IconButton(systemName: "trash", action: onDelete, tooltip: "Delete")
                            .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                    }
                }
            }
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
        .contextMenu {
            ImageContextMenu(
                image: image,
                onPull: onPull ?? {},
                onRemove: onDelete,
                onInspect: onInspect ?? {},
                onTag: onTag ?? {},
                onPush: onPush ?? {},
                onSave: onSave ?? {}
            )
        }
        .disabled(isPending)
    }

    private var imageBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.18) : badgeColor.opacity(0.18))
                .frame(width: 34, height: 34)

            SwiftUI.Image(systemName: badgeSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : badgeColor)
        }
    }

    private var badgeSymbol: String {
        if isDangling {
            return "cube.transparent"
        }
        if usageSummary != nil {
            return "shippingbox.fill"
        }
        return "square.3.layers.3d"
    }

    private var badgeColor: Color {
        if isDangling {
            return .orange
        }
        if usageSummary != nil {
            return AppTheme.accentColor
        }
        return .blue
    }

    private var metadataText: String {
        var parts: [String] = []

        if let usageSummary, !usageSummary.isEmpty {
            parts.append(usageSummary.replacingOccurrences(of: "\n", with: " "))
        }

        parts.append(image.sizeFormatted)

        if !image.createdRelativeDisplay.isEmpty {
            parts.append(image.createdRelativeDisplay)
        }

        if isDangling {
            parts.append("Dangling")
        }

        return parts.joined(separator: "  •  ")
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
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var tooltip: String = ""

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

#Preview {
    ImageRowView(
        image: Image(
            id: "sha256:1234567890abcdef",
            repository: "nginx",
            tag: "latest",
            size: 133000000,
            created: "2 weeks ago"
        ),
        isSelected: true,
        onDelete: {}
    )
}
