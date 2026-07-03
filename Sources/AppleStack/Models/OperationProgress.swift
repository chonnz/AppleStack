import Foundation

struct OperationProgress: Equatable {
    let title: String
    var detail: String
    var log: String
    var isRunning: Bool
    let startedAt: Date

    init(
        title: String,
        detail: String,
        log: String = "",
        isRunning: Bool = true,
        startedAt: Date = Date()
    ) {
        self.title = title
        self.detail = detail
        self.log = log
        self.isRunning = isRunning
        self.startedAt = startedAt
    }

    mutating func append(_ chunk: String, maxLogLength: Int = 12_000) {
        log += chunk

        if log.count > maxLogLength {
            log = String(log.suffix(maxLogLength))
        }

        let latestLine = chunk
            .split(whereSeparator: \.isNewline)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let latestLine, !latestLine.isEmpty {
            detail = latestLine
        }
    }

    mutating func finish(_ message: String) {
        detail = message
        isRunning = false
    }
}
