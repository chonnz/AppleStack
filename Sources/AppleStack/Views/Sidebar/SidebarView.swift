import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "photo.stack"
        case .system: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedSection: SidebarSection

    var body: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .tag(section)
        }
        .navigationTitle("AppleStack")
    }
}

#Preview {
    @Previewable @State var selected: SidebarSection = .containers
    SidebarView(selectedSection: $selected)
}
