import Foundation

struct ContainerConfig {
    var name: String
    var image: String
    var cpus: Int
    var memory: String
    var ports: String
    var env: [String: String]
    var envFiles: [String]
    var volumes: [String]
    var mounts: [String]
    var labels: [String]
    var networks: [String]
    var detach: Bool
    var interactive: Bool
    var tty: Bool
    var autoRemove: Bool
    var dns: String
    var dnsDomain: String
    var dnsSearch: [String]
    var dnsOptions: [String]
    var noDNS: Bool
    var entrypoint: String
    var workdir: String
    var user: String
    var uid: String
    var gid: String
    var ulimits: [String]
    var platform: String
    var arch: String
    var os: String
    var kernel: String
    var runtime: String
    var initProcess: Bool
    var initImage: String
    var readOnly: Bool
    var rosetta: Bool
    var ssh: Bool
    var virtualization: Bool
    var shmSize: String
    var tmpfs: [String]
    var capAdd: [String]
    var capDrop: [String]
    var scheme: String
    var maxConcurrentDownloads: String

    init(
        name: String = "",
        image: String = "",
        cpus: Int = 2,
        memory: String = "512m",
        ports: String = "",
        env: [String: String] = [:],
        envFiles: [String] = [],
        volumes: [String] = [],
        mounts: [String] = [],
        labels: [String] = [],
        networks: [String] = [],
        detach: Bool = true,
        interactive: Bool = false,
        tty: Bool = false,
        autoRemove: Bool = false,
        dns: String = "",
        dnsDomain: String = "",
        dnsSearch: [String] = [],
        dnsOptions: [String] = [],
        noDNS: Bool = false,
        entrypoint: String = "",
        workdir: String = "",
        user: String = "",
        uid: String = "",
        gid: String = "",
        ulimits: [String] = [],
        platform: String = "",
        arch: String = "",
        os: String = "",
        kernel: String = "",
        runtime: String = "",
        initProcess: Bool = false,
        initImage: String = "",
        readOnly: Bool = false,
        rosetta: Bool = false,
        ssh: Bool = false,
        virtualization: Bool = false,
        shmSize: String = "",
        tmpfs: [String] = [],
        capAdd: [String] = [],
        capDrop: [String] = [],
        scheme: String = "",
        maxConcurrentDownloads: String = ""
    ) {
        self.name = name
        self.image = image
        self.cpus = cpus
        self.memory = memory
        self.ports = ports
        self.env = env
        self.envFiles = envFiles
        self.volumes = volumes
        self.mounts = mounts
        self.labels = labels
        self.networks = networks
        self.detach = detach
        self.interactive = interactive
        self.tty = tty
        self.autoRemove = autoRemove
        self.dns = dns
        self.dnsDomain = dnsDomain
        self.dnsSearch = dnsSearch
        self.dnsOptions = dnsOptions
        self.noDNS = noDNS
        self.entrypoint = entrypoint
        self.workdir = workdir
        self.user = user
        self.uid = uid
        self.gid = gid
        self.ulimits = ulimits
        self.platform = platform
        self.arch = arch
        self.os = os
        self.kernel = kernel
        self.runtime = runtime
        self.initProcess = initProcess
        self.initImage = initImage
        self.readOnly = readOnly
        self.rosetta = rosetta
        self.ssh = ssh
        self.virtualization = virtualization
        self.shmSize = shmSize
        self.tmpfs = tmpfs
        self.capAdd = capAdd
        self.capDrop = capDrop
        self.scheme = scheme
        self.maxConcurrentDownloads = maxConcurrentDownloads
    }
}
