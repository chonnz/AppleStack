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

    var reference: String {
        tag.isEmpty ? repository : "\(repository):\(tag)"
    }

    var shortID: String {
        String(id.replacingOccurrences(of: "sha256:", with: "").prefix(12))
    }

    var displayTitle: String {
        let trimmedRepository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRepository.isEmpty || trimmedRepository == "<none>" {
            return shortID
        }
        return reference
    }

    var deleteTarget: String {
        let trimmedRepository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRepository.isEmpty || trimmedRepository == "<none>" {
            return id
        }
        return reference
    }

    var createdRelativeDisplay: String {
        guard let date = Self.parseISO8601(created) else { return created }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private static func parseISO8601(_ rawValue: String) -> Date? {
        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }
}
