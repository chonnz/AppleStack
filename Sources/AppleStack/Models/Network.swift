import Foundation

/// 网络模型
struct Network: Identifiable, Hashable {
    let id: String
    let name: String
    let driver: String
    let scope: String
    let ipamDriver: String
    let subnet: String
    let gateway: String
    let containers: Int

    init(
        id: String,
        name: String,
        driver: String = "bridge",
        scope: String = "local",
        ipamDriver: String = "default",
        subnet: String = "",
        gateway: String = "",
        containers: Int = 0
    ) {
        self.id = id
        self.name = name
        self.driver = driver
        self.scope = scope
        self.ipamDriver = ipamDriver
        self.subnet = subnet
        self.gateway = gateway
        self.containers = containers
    }
}

/// 网络创建配置
struct NetworkConfig {
    var name: String
    var driver: String
    var subnet: String
    var gateway: String
    var isInternal: Bool

    init(
        name: String = "",
        driver: String = "bridge",
        subnet: String = "",
        gateway: String = "",
        isInternal: Bool = false
    ) {
        self.name = name
        self.driver = driver
        self.subnet = subnet
        self.gateway = gateway
        self.isInternal = isInternal
    }
}
