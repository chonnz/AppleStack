import Foundation

/// 机器（Linux 虚拟机）模型
struct Machine: Identifiable, Hashable {
    let id: String
    let name: String
    let status: MachineStatus
    let image: String
    let cpus: Int
    let memory: String
    let disk: String
    let ip: String
    let created: String

    init(
        id: String,
        name: String,
        status: MachineStatus = .stopped,
        image: String = "",
        cpus: Int = 2,
        memory: String = "2g",
        disk: String = "20g",
        ip: String = "",
        created: String = ""
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.image = image
        self.cpus = cpus
        self.memory = memory
        self.disk = disk
        self.ip = ip
        self.created = created
    }
}

/// 机器状态
enum MachineStatus: String, CaseIterable, Codable {
    case running = "Running"
    case stopped = "Stopped"
    case creating = "Creating"
    case error = "Error"

    var color: String {
        switch self {
        case .running: return "green"
        case .stopped: return "gray"
        case .creating: return "orange"
        case .error: return "red"
        }
    }
}

/// 机器创建配置
struct MachineConfig {
    var name: String
    var image: String
    var cpus: Int
    var memory: String
    var disk: String

    init(
        name: String = "",
        image: String = "ubuntu:latest",
        cpus: Int = 2,
        memory: String = "2g",
        disk: String = "20g"
    ) {
        self.name = name
        self.image = image
        self.cpus = cpus
        self.memory = memory
        self.disk = disk
    }
}
