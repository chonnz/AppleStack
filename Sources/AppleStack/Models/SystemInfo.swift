import Foundation

struct SystemInfo: Codable {
    let version: String
    let os: String
    let kernel: String
    let arch: String
    let isServiceRunning: Bool
    let containersRunning: Int
    let containersStopped: Int
    let images: Int

    var isRunning: Bool {
        isServiceRunning
    }
}
