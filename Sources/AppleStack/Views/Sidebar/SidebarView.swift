import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: AppSection
    @AppStorage("appLanguage") private var appLanguageRaw = "en"

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarGroupLabel(localized("Getting Started"))

                    SidebarItem(title: localized("Quick Start"), icon: "sparkles", isSelected: selectedSection == .quickStart) {
                        selectedSection = .quickStart
                    }

                    SidebarGroupLabel(localized("Containers"))
                        .padding(.top, 10)

                    SidebarItem(title: localized("Containers"), icon: "cube.box.fill", isSelected: selectedSection == .containers) {
                        selectedSection = .containers
                    }
                    SidebarItem(title: localized("Images"), icon: "square.3.layers.3d.down.right", isSelected: selectedSection == .images) {
                        selectedSection = .images
                    }
                    SidebarItem(title: localized("Volumes"), icon: "externaldrive", isSelected: selectedSection == .volumes) {
                        selectedSection = .volumes
                    }
                    SidebarItem(title: localized("Networks"), icon: "network", isSelected: selectedSection == .networks) {
                        selectedSection = .networks
                    }

                    SidebarGroupLabel("Linux")
                        .padding(.top, 10)

                    SidebarItem(title: localized("Machines"), icon: "desktopcomputer", isSelected: selectedSection == .machines) {
                        selectedSection = .machines
                    }

                    SidebarGroupLabel(localized("General"))
                        .padding(.top, 10)

                    SidebarItem(title: localized("Registry"), icon: "key.fill", isSelected: selectedSection == .registry) {
                        selectedSection = .registry
                    }
                    SidebarItem(title: localized("Activity Monitor"), icon: "chart.line.uptrend.xyaxis", isSelected: selectedSection == .activityMonitor) {
                        selectedSection = .activityMonitor
                    }
                    SidebarItem(title: localized("Commands"), icon: "terminal.fill", isSelected: selectedSection == .commands) {
                        selectedSection = .commands
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
        .background(AppTheme.sidebarBackground)
    }

    private func localized(_ value: String) -> String {
        language.localized(value)
    }
}

private struct SidebarGroupLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.sidebarGroupText)
            .padding(.horizontal, 11)
            .padding(.top, 4)
            .padding(.bottom, 5)
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
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
