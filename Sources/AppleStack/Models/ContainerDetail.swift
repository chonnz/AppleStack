import Foundation

struct ContainerDetail: Codable {
    let id: String
    let name: String
    let image: String
    let state: ContainerState
    let config: ContainerConfigDetail
    let networkSettings: NetworkSettings
    let mounts: [MountInfo]
}

struct ContainerConfigDetail: Codable {
    let cpus: Int
    let memory: String
    let env: [String: String]
    let workingDir: String
}

struct NetworkSettings: Codable {
    let ipAddress: String
    let macAddress: String
    let gateway: String
}

struct MountInfo: Codable {
    let type: String
    let source: String
    let destination: String
    let readOnly: Bool
}
