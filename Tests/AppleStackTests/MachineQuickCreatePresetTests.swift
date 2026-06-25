import Testing
@testable import AppleStack

struct MachineQuickCreatePresetTests {
    @Test func recommendedTemplateUsesFriendlyDefaults() {
        let template = MachineSystemTemplate.recommended

        #expect(template.title == "Ubuntu 24.04 LTS")
        #expect(template.badge == "Recommended")
        #expect(template.defaultMachineName == "ubuntu-dev")
        #expect(template.internalImageTag == "applestack/machine-ubuntu:24.04")
    }

    @Test func standardPresetBuildsReadyToStartConfig() {
        let config = MachineConfig.quickCreate(
            name: "dev",
            template: .recommended,
            resources: .standard,
            homeMount: "rw",
            setDefault: true,
            startAfterCreate: true
        )

        #expect(config.name == "dev")
        #expect(config.image == "applestack/machine-ubuntu:24.04")
        #expect(config.cpus == 4)
        #expect(config.memory == "4G")
        #expect(config.homeMount == "rw")
        #expect(config.setDefault)
        #expect(!config.noBoot)
    }
}
