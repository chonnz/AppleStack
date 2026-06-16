import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        StatusBadge(text: "Running", color: .green)
        StatusBadge(text: "Exited", color: .red)
        StatusBadge(text: "Paused", color: .yellow)
        StatusBadge(text: "Created", color: .gray)
    }
    .padding()
}
