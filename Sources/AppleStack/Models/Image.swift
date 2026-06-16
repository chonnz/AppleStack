import Foundation

struct Image: Identifiable, Hashable {
    let id: String
    let repository: String
    let tag: String
    let size: Int64
    let created: String

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
