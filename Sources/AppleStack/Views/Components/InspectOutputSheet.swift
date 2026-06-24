import SwiftUI

struct InspectOutputSheet: View {
    let title: String
    let output: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(language.localized("Done")) { dismiss() }
            }
            .padding()

            Divider()

            ScrollView([.horizontal, .vertical]) {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
