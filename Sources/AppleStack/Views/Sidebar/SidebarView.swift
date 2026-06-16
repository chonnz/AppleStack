import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"
    case machines = "Machines"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .containers: "square.stack"
        case .images: "photo.stack"
        case .volumes: "externaldrive"
        case .networks: "network"
        case .machines: "desktopcomputer"
        case .system: "gearshape"
        }
    }

    var category: SidebarCategory {
        switch self {
        case .dashboard: .general
        case .containers, .images, .volumes, .networks: .docker
        case .machines: .linux
        case .system: .general
        }
    }
}

enum SidebarCategory: String, CaseIterable {
    case docker = "Docker"
    case linux = "Linux"
    case general = "General"
}

struct SidebarView: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Docker section
            SidebarCategoryHeader(title: "Docker")
            VStack(spacing: 1) {
                ForEach([AppSection.containers, .images, .volumes, .networks], id: \.self) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 8)

            // Linux section
            SidebarCategoryHeader(title: "Linux")
            VStack(spacing: 1) {
                SidebarItem(
                    section: .machines,
                    isSelected: selectedSection == .machines
                ) {
                    selectedSection = .machines
                }
            }
            .padding(.horizontal, 8)

            // General section
            SidebarCategoryHeader(title: "General")
            VStack(spacing: 1) {
                ForEach([AppSection.dashboard, .system], id: \.self) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(width: 180)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SidebarCategoryHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

private struct SidebarItem: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SwiftUI.Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .frame(width: 20, height: 20)
                Text(section.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.purple : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

#Preview {
    @Previewable @State var selected: AppSection = .containers
    SidebarView(selectedSection: $selected)
}
