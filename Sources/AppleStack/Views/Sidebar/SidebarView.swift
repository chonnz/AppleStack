import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SidebarGroup(title: "Docker", sections: [.containers, .volumes, .images, .networks], selectedSection: $selectedSection)
                    
                    SidebarGroup(title: "Linux", sections: [.machines], selectedSection: $selectedSection)
                    
                    SidebarGroup(title: "Tools", sections: [.registry, .builder], selectedSection: $selectedSection)
                    
                    SidebarGroup(title: "General", sections: [.dashboard, .system], selectedSection: $selectedSection)
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

struct SidebarGroup: View {
    let title: String
    let sections: [AppSection]
    @Binding var selectedSection: AppSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.sidebarGroupText)
                .padding(.leading, 10)
                .padding(.bottom, 4)
            
            ForEach(sections, id: \.self) { section in
                SidebarItem(
                    title: section.rawValue,
                    icon: section.icon,
                    isSelected: selectedSection == section
                ) {
                    selectedSection = section
                }
            }
        }
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
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .foregroundStyle(AppTheme.sidebarText)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? AppTheme.sidebarSelection : (isHovered ? AppTheme.sidebarHover : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
