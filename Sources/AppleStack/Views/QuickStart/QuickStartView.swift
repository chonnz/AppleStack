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
                VStack(alignment: .leading, spacing: 16) {
                    heroPanel

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                        quickActionCard(
                            title: language.localized("Start the system"),
                            subtitle: language.localized("Turn on Apple Containers before creating or running anything."),
                            icon: "power",
                            isBusy: isStartingSystem,
                            action: startSystem
                        )

                        quickActionCard(
                            title: language.localized("Create a container"),
                            subtitle: language.localized("Run an app from an image with only a name and image."),
                            icon: "cube.box.fill",
                            action: onCreateContainer
                        )

                        quickActionCard(
                            title: language.localized("Create a virtual machine"),
                            subtitle: language.localized("Create a Linux machine from a preset image."),
                            icon: "desktopcomputer",
                            action: onCreateMachine
                        )

                        quickActionCard(
                            title: language.localized("Open Activity Monitor"),
                            subtitle: language.localized("See CPU, memory, network, and disk usage."),
                            icon: "chart.line.uptrend.xyaxis",
                            action: onOpenActivityMonitor
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 2)
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

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accentColor)
                    SwiftUI.Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                .shadow(color: AppTheme.accentColor.opacity(0.22), radius: 18, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text(language.localized("Manage containers without memorizing commands."))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(language.localized("Start the runtime, create what you need, then watch usage from one place."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                stepPill(number: "1", title: language.localized("Start"))
                stepPill(number: "2", title: language.localized("Create"))
                stepPill(number: "3", title: language.localized("Observe"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.chromeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
        )
    }

    private func stepPill(number: String, title: String) -> some View {
        HStack(spacing: 7) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppTheme.accentColor))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.badgeBackground.opacity(0.82))
        )
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        icon: String,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
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

                ZStack {
                    Circle()
                        .fill(AppTheme.badgeBackground)
                    SwiftUI.Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accentColor)
                }
                .frame(width: 24, height: 24)
                .padding(.top, 1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.chromeBackground)
            )
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
