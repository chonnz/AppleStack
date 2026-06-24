import SwiftUI

enum ModuleTint {
    static let containers = Color(hex: "#E67E22")
    static let images = Color(hex: "#9B59B6")
    static let volumes = Color(hex: "#3498DB")
    static let networks = Color(hex: "#2ECC71")
    static let machines = Color(hex: "#1ABC9C")
    static let registry = Color(hex: "#F39C12")
    static let activityMonitor = Color(hex: "#E74C3C")
    static let commands = Color(hex: "#16A085")
    static let builder = Color(hex: "#95A5A6")
    static let dashboard = Color(hex: "#E74C3C")
    static let system = Color(hex: "#7F8C8D")
}

enum AppTheme {
    static let accentColor = Color(hex: "#7D30A5")
    static let sidebarText = Color.primary
    static let sidebarGroupText = Color.secondary.opacity(0.75)
    static let paneBackground = Color(nsColor: .textBackgroundColor)
    static let chromeBackground = Color(nsColor: .windowBackgroundColor)
    static let subtleBorder = Color(nsColor: .separatorColor).opacity(0.55)
    static let sidebarSelection = accentColor.opacity(0.18)
    static let sidebarHover = Color(nsColor: .quaternaryLabelColor).opacity(0.1)
    static let listSelection = accentColor.opacity(0.94)
    static let listHover = Color(nsColor: .quaternaryLabelColor).opacity(0.16)
    static let inspectorCardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.78)
    static let inspectorRowDivider = Color(nsColor: .separatorColor).opacity(0.34)
    static let detailTabBackground = Color(nsColor: .controlBackgroundColor).opacity(0.68)
    static let detailTabSelectedBackground = Color(nsColor: .windowBackgroundColor)
    static let badgeBackground = accentColor.opacity(0.14)
    static let badgeForeground = accentColor
    static let terminalBackground = Color(nsColor: .textBackgroundColor)
    static let terminalSecondaryBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let terminalBorder = Color(nsColor: .separatorColor).opacity(0.38)
    // 侧边栏折叠后，系统红绿灯和侧边栏按钮会占用左上角区域，标题需要像 OrbStack 一样向右避让。
    static let windowControlsClearance: CGFloat = 142
}

struct PaneHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    let leadingAccessory: AnyView?
    let leadingInset: CGFloat
    @ViewBuilder let actions: Actions

    init(
        title: String,
        subtitle: String? = nil,
        leadingAccessory: AnyView? = nil,
        leadingInset: CGFloat = 0,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingAccessory = leadingAccessory
        self.leadingInset = leadingInset
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalHeader
            verticalHeader
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(minHeight: 60, alignment: .top)
        .background(AppTheme.paneBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var horizontalHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            if let leadingAccessory {
                leadingAccessory
            }

            titleBlock
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: leadingInset)

            Spacer(minLength: 12)
            actions
        }
    }

    private var verticalHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                if let leadingAccessory {
                    leadingAccessory
                }

                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: leadingInset)
            }

            HStack {
                Spacer(minLength: 0)
                actions
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct HeaderPill<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.chromeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 0.5)
        )
    }
}

struct HeaderCircleButton: View {
    let systemName: String
    let action: () -> Void
    var helpText: String?

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppTheme.chromeBackground)
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(helpText ?? "")
    }
}

struct HeaderMenuButton<MenuItems: View>: View {
    var systemName: String = "ellipsis"
    var helpText: String?
    @ViewBuilder let content: MenuItems

    init(
        systemName: String = "ellipsis",
        helpText: String? = nil,
        @ViewBuilder content: () -> MenuItems
    ) {
        self.systemName = systemName
        self.helpText = helpText
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppTheme.chromeBackground)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(helpText ?? "")
    }
}

struct HeaderSearchToggle: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    var placeholder: String = "Search"
    var width: CGFloat = 150

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isExpanded {
                HeaderPill {
                    HStack(spacing: 6) {
                        SwiftUI.Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        TextField(placeholder, text: $text)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .frame(width: width)
                            .focused($isFocused)

                        Button {
                            text = ""
                            isExpanded = false
                        } label: {
                            SwiftUI.Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
            } else {
                HeaderCircleButton(
                    systemName: "magnifyingglass",
                    action: { isExpanded = true },
                    helpText: "Search"
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }
}

/// 通用信息行组件
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 13))
        .padding(.vertical, 2)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .frame(width: 90)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.paneBackground)
        )
    }
}
