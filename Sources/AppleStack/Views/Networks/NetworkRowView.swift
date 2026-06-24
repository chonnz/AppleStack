import SwiftUI

struct NetworkRowView: View {
    let network: Network
    let isSelected: Bool
    let isPending: Bool
    let onDelete: () -> Void
    let onInspect: () -> Void

    @State private var isHovered = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.18) : Color.blue.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay {
                    SwiftUI.Image(systemName: "network")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(network.name)
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
                        .frame(width: 52, alignment: .trailing)
                } else {
                    HStack(spacing: 4) {
                        Button(action: onInspect) {
                            SwiftUI.Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                        .help(language.localized("Inspect network"))

                        Button(action: onDelete) {
                            SwiftUI.Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : .secondary)
                        .help(language.localized("Delete network"))
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
            Button(language.localized("Inspect")) {
                onInspect()
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text(language.localized("Delete"))
            }
        }
        .disabled(isPending)
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

    private var metadataText: String {
        var parts = [network.driver, network.scope]

        if !network.gateway.isEmpty {
            parts.append(network.gateway)
        } else if !network.subnet.isEmpty {
            parts.append(network.subnet)
        }

        return parts.joined(separator: "  •  ")
    }
}

#Preview {
    NetworkRowView(
        network: Network(
            id: "abc123",
            name: "my-network",
            driver: "bridge",
            scope: "local",
            containers: 3
        ),
        isSelected: true,
        isPending: false,
        onDelete: {},
        onInspect: {}
    )
}
