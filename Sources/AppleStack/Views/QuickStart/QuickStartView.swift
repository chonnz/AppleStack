import SwiftUI

struct QuickStartView: View {
    let onStartSystem: () async throws -> Void
    let onCreateContainer: () -> Void
    let onCreateMachine: () -> Void
    let onOpenActivityMonitor: () -> Void

    @State private var isStartingSystem = false
    @State private var errorMessage: String?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: language.localized("Quick Start"), subtitle: language.localized("Start using Apple containers in a few clicks.")) {}

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(language.localized("What do you want to do?"))
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.top, 2)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                        quickActionCard(
                            title: language.localized("Start the system"),
                            subtitle: language.localized("Turn on Apple Containers before creating or running anything."),
                            icon: "power",
                            tint: .green,
                            isBusy: isStartingSystem,
                            action: startSystem
                        )

                        quickActionCard(
                            title: language.localized("Create a container"),
                            subtitle: language.localized("Run an app from an image with only a name and image."),
                            icon: "cube.box.fill",
                            tint: ModuleTint.containers,
                            action: onCreateContainer
                        )

                        quickActionCard(
                            title: language.localized("Create a virtual machine"),
                            subtitle: language.localized("Create a Linux machine from a preset image."),
                            icon: "desktopcomputer",
                            tint: ModuleTint.machines,
                            action: onCreateMachine
                        )

                        quickActionCard(
                            title: language.localized("Open Activity Monitor"),
                            subtitle: language.localized("See CPU, memory, network, and disk usage."),
                            icon: "chart.line.uptrend.xyaxis",
                            tint: ModuleTint.activityMonitor,
                            action: onOpenActivityMonitor
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(24)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AppTheme.paneBackground)
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.14))
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 5)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(AppTheme.chromeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func startSystem() {
        Task {
            guard !isStartingSystem else { return }
            isStartingSystem = true
            errorMessage = nil
            defer { isStartingSystem = false }

            do {
                try await onStartSystem()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    QuickStartView(
        onStartSystem: {},
        onCreateContainer: {},
        onCreateMachine: {},
        onOpenActivityMonitor: {}
    )
}
