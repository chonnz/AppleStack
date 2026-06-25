import Foundation
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

    @Test func systemTemplateBuildOptionsUseAbsoluteContainerfilePath() {
        let directory = URL(fileURLWithPath: "/tmp/applestack-template", isDirectory: true)

        let options = MachineSystemTemplate.recommended.buildOptions(in: directory)

        #expect(options.contextDirectory == "/tmp/applestack-template")
        #expect(options.dockerfilePath == "/tmp/applestack-template/Containerfile")
        #expect(options.tags == ["applestack/machine-ubuntu:24.04"])
        #expect(options.platform == "linux/arm64")
        #expect(options.dns == "8.8.8.8")
    }
}
