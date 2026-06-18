import SwiftUI

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct InspectorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.inspectorCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct InspectorDataRow {
    let label: String
    let value: String
    var usesMonospacedFont: Bool = false

    var hasContent: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct InspectorRows: View {
    let rows: [InspectorDataRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                InspectorRow(row: row)
                if index < rows.count - 1 {
                    Divider()
                        .overlay(AppTheme.inspectorRowDivider)
                }
            }
        }
    }
}

struct InspectorRow: View {
    let row: InspectorDataRow

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(row.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)

            Spacer(minLength: 0)

            Group {
                if row.usesMonospacedFont {
                    Text(row.value)
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    Text(row.value)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }
}

struct InspectorKeyValueItem {
    let key: String
    let value: String
}

struct InspectorKeyValueTable: View {
    let items: [InspectorKeyValueItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Value")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 16) {
                    Text(item.key)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 170, alignment: .leading)

                    Spacer(minLength: 0)

                    Text(item.value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)

                if index < items.count - 1 {
                    Divider()
                        .overlay(AppTheme.inspectorRowDivider)
                }
            }
        }
    }
}

struct InspectorTagFlow: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.detailTabBackground)
                    .clipShape(Capsule())
                    .textSelection(.enabled)
            }
        }
    }
}

func inspectorFormatTimestamp(_ rawValue: String) -> String {
    guard !rawValue.isEmpty else { return "" }
    guard let date = inspectorParseISO8601(rawValue) else { return rawValue }

    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.unitsStyle = .full
    let relative = relativeFormatter.localizedString(for: date, relativeTo: .now)

    let absolute = date.formatted(
        .dateTime
            .year()
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
    )

    return "\(relative) (\(absolute))"
}

func inspectorFormatBytes(_ rawValue: Any?) -> String? {
    let byteCount: Int64?

    if let value = rawValue as? Int64 {
        byteCount = value
    } else if let value = rawValue as? Int {
        byteCount = Int64(value)
    } else if let value = rawValue as? Double {
        byteCount = Int64(value)
    } else {
        byteCount = nil
    }

    guard let byteCount else { return nil }

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: byteCount)
}

func inspectorFormatCommand(_ rawValue: Any?) -> String {
    if let values = rawValue as? [String], !values.isEmpty {
        return values.joined(separator: " ")
    }
    if let value = rawValue as? String {
        return value
    }
    return ""
}

func inspectorParseEnvironment(_ rawValue: Any?) -> [InspectorKeyValueItem] {
    guard let values = rawValue as? [String] else { return [] }

    return values.map { entry in
        let parts = entry.split(separator: "=", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return InspectorKeyValueItem(key: parts[0], value: parts[1])
        }
        return InspectorKeyValueItem(key: entry, value: "")
    }
}

func inspectorParseISO8601(_ rawValue: String) -> Date? {
    let formatterWithFractionalSeconds = ISO8601DateFormatter()
    formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatterWithFractionalSeconds.date(from: rawValue) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: rawValue)
}
