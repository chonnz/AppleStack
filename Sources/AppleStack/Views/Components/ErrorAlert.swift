import SwiftUI

struct ErrorAlert: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    init(title: String = "Error", message: String, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 16) {
            SwiftUI.Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 12) {
                if let onRetry {
                    Button(language.localized("Retry")) {
                        onRetry()
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(language.localized("OK")) {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview {
    ErrorAlert(
        title: "Connection Failed",
        message: "Unable to connect to the container runtime. Please check if the service is running.",
        onDismiss: {},
        onRetry: {}
    )
}
