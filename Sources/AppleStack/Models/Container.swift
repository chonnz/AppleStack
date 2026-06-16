import Foundation

struct Container: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: ContainerStatus
    let state: ContainerState
    let created: String
    let ports: String
    let cpus: Int
    let memory: String

    var statusColor: String {
        switch state {
        case .running: return "green"
        case .exited: return "red"
        case .paused: return "yellow"
        case .created: return "gray"
        }
    }
}

enum ContainerStatus: String, Codable {
    case running
    case stopped
    case paused
    case created
    case restarting
}

enum ContainerState: String, Codable {
    case running
    case exited
    case paused
    case created
}
