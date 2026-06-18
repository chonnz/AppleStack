import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarItem(title: "Containers", icon: "cube.box.fill", iconTint: ModuleTint.containers, isSelected: selectedSection == .containers) {
                        selectedSection = .containers
                    }
                    SidebarItem(title: "Images", icon: "square.3.layers.3d.down.right", iconTint: ModuleTint.images, isSelected: selectedSection == .images) {
                        selectedSection = .images
                    }
                    SidebarItem(title: "Volumes", icon: "externaldrive", iconTint: ModuleTint.volumes, isSelected: selectedSection == .volumes) {
                        selectedSection = .volumes
                    }
                    SidebarItem(title: "Networks", icon: "network", iconTint: ModuleTint.networks, isSelected: selectedSection == .networks) {
                        selectedSection = .networks
                    }

                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    SidebarItem(title: "Machines", icon: "desktopcomputer", iconTint: ModuleTint.machines, isSelected: selectedSection == .machines) {
                        selectedSection = .machines
                    }

                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    SidebarItem(title: "Registry", icon: "person.crop.circle.badge.key", iconTint: ModuleTint.registry, isSelected: selectedSection == .registry) {
                        selectedSection = .registry
                    }
                    SidebarItem(title: "Builder", icon: "hammer", iconTint: ModuleTint.builder, isSelected: selectedSection == .builder) {
                        selectedSection = .builder
                    }

                    Divider()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    SidebarItem(title: "Dashboard", icon: "chart.bar.fill", iconTint: ModuleTint.dashboard, isSelected: selectedSection == .dashboard) {
                        selectedSection = .dashboard
                    }
                    SidebarItem(title: "System", icon: "gearshape", iconTint: ModuleTint.system, isSelected: selectedSection == .system) {
                        selectedSection = .system
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
            }

            Spacer()

            HStack(spacing: 10) {
                SwiftUI.Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary.opacity(0.9))
                Text("AppleStack")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .background(AppTheme.chromeBackground)
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let iconTint: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : iconTint)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : AppTheme.sidebarText)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AppTheme.accentColor : (isHovered ? AppTheme.sidebarHover : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    @Previewable @State var selected: AppSection = .containers
    SidebarView(selectedSection: $selected)
}
