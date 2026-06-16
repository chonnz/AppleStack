import Foundation

struct ContainerConfig {
    var name: String
    var image: String
    var cpus: Int
    var memory: String
    var ports: String
    var env: [String: String]
    var volumes: [String]
    var detach: Bool

    init(
        name: String = "",
        image: String = "",
        cpus: Int = 2,
        memory: String = "512m",
        ports: String = "",
        env: [String: String] = [:],
        volumes: [String] = [],
        detach: Bool = true
    ) {
        self.name = name
        self.image = image
        self.cpus = cpus
        self.memory = memory
        self.ports = ports
        self.env = env
        self.volumes = volumes
        self.detach = detach
    }
}
