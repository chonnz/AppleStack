import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "搜索..."

    var body: some View {
        HStack(spacing: 8) {
            SwiftUI.Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SearchField(text: .constant("test"))
}
