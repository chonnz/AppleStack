import Foundation

/// 镜像构建参数
struct ImageBuildOptions {
    var contextDirectory: String
    var dockerfilePath: String?
    var tags: [String]
    var platform: String?
    var dns: String?
    var buildArgs: [String: String]
    var noCache: Bool
    var pull: Bool

    init(
        contextDirectory: String = ".",
        dockerfilePath: String? = nil,
        tags: [String] = [],
        platform: String? = nil,
        dns: String? = nil,
        buildArgs: [String: String] = [:],
        noCache: Bool = false,
        pull: Bool = false
    ) {
        self.contextDirectory = contextDirectory
        self.dockerfilePath = dockerfilePath
        self.tags = tags
        self.platform = platform
        self.dns = dns
        self.buildArgs = buildArgs
        self.noCache = noCache
        self.pull = pull
    }
}
