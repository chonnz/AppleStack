import Testing
@testable import AppleStack

struct DetailIdentityTests {
    @Test func containerDetailIdentityChangesWithSelectedContainer() {
        let redis = Container(
            id: "redis",
            name: "redis",
            image: "redis:latest",
            status: .running,
            state: .running,
            created: "",
            ports: "",
            cpus: 1,
            memory: "512m"
        )
        let buildkit = Container(
            id: "buildkit",
            name: "buildkit",
            image: "builder:latest",
            status: .running,
            state: .running,
            created: "",
            ports: "",
            cpus: 1,
            memory: "512m"
        )

        #expect(detailPanelIdentity(section: .containers, selectedContainer: redis, selectedImage: nil, selectedVolume: nil, selectedNetwork: nil, selectedMachine: nil) == "containers.redis")
        #expect(detailPanelIdentity(section: .containers, selectedContainer: buildkit, selectedImage: nil, selectedVolume: nil, selectedNetwork: nil, selectedMachine: nil) == "containers.buildkit")
    }
}
