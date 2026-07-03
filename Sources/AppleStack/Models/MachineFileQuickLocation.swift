import Foundation

struct MachineFileQuickLocation: Identifiable, Equatable {
    let title: String
    let path: String

    var id: String { path }

    static let defaults: [MachineFileQuickLocation] = [
        .init(title: "Root", path: "/"),
        .init(title: "Home", path: "/home"),
        .init(title: "Config", path: "/etc"),
        .init(title: "Logs", path: "/var/log"),
    ]
}

enum MachineFileBrowserErrorMessage {
    static func describe(_ error: Error, path: String) -> String {
        let rawMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = rawMessage.lowercased()
        let reason: String

        if lowercased.contains("permission denied") {
            reason = "Permission denied for \(path)."
        } else if lowercased.contains("no such file") || lowercased.contains("cannot access") {
            reason = "The path \(path) could not be opened."
        } else {
            reason = "Could not open \(path)."
        }

        guard !rawMessage.isEmpty else { return reason }
        return "\(reason)\n\(rawMessage)"
    }
}
