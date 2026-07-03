import SwiftUI

struct OperationProgressView: View {
    let progress: OperationProgress
    var onDismiss: (() -> Void)?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if progress.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    SwiftUI.Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.localized(progress.title))
                        .font(.system(size: 13, weight: .semibold))
                    Text(language.localized(progress.detail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if !progress.isRunning, let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        SwiftUI.Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(language.localized("Dismiss"))
                }
            }

            if !progress.log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(progress.log)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 120)
                .background(AppTheme.fileBrowserBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .padding(12)
        .background(AppTheme.chromeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
        )
    }
}
