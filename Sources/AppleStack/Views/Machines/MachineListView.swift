import AppKit
import SwiftUI

struct MachineListView: View {
    private static let lastBuiltMachineImageReferenceKey = "appleStack.lastBuiltMachineImageReference"
    private static let machineInitCheckSuccessMarker = "__APPLESTACK_MACHINE_INIT_OK__"
    private static let machineInitCheckMissingMarker = "__APPLESTACK_MACHINE_INIT_MISSING__"
    private static let machineStarterTemplate = """
    FROM ubuntu:24.04

    ENV container docker

    RUN apt-get update && \
        apt-get install -y systemd systemd-sysv dbus sudo iproute2 iputils-ping curl vim && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        : > /etc/machine-id && \
        : > /var/lib/dbus/machine-id && \
        systemctl mask systemd-firstboot.service systemd-resolved.service \
            dev-hugepages.mount sys-fs-fuse-connections.mount \
            systemd-remount-fs.service getty.target console-getty.service systemd-logind.service && \
        systemctl set-default multi-user.target

    VOLUME ["/sys/fs/cgroup"]

    STOPSIGNAL SIGRTMIN+3

    CMD ["/sbin/init"]
    """

    private struct MachineImageVersion: Identifiable {
        let id: String
        let title: String
        let image: String
        let description: String
    }

    private struct MachineDistribution: Identifiable {
        let id: String
        let title: String
        let versions: [MachineImageVersion]
    }

    private struct MachineHomeMountOption: Identifiable {
        let value: String
        let title: String
        let description: String

        var id: String { value }
    }

    private enum MachineImageValidationResult {
        case valid
        case missingInit
        case inconclusive(String?)
    }

    private static let machineDistributions: [MachineDistribution] = [
        .init(id: "alpine", title: "Alpine", versions: [
            .init(id: "3.22", title: "3.22", image: "alpine:3.22", description: "Generic Alpine OCI image, boot compatibility may vary"),
            .init(id: "3.21", title: "3.21", image: "alpine:3.21", description: "Generic Alpine OCI image, boot compatibility may vary"),
            .init(id: "latest", title: "Latest", image: "alpine:latest", description: "Generic Alpine OCI image, boot compatibility may vary"),
        ]),
        .init(id: "ubuntu", title: "Ubuntu", versions: [
            .init(id: "26.04", title: "26.04 LTS", image: "ubuntu:26.04", description: "Generic Ubuntu OCI image, boot compatibility may vary"),
            .init(id: "24.04", title: "24.04 LTS", image: "ubuntu:24.04", description: "Generic Ubuntu OCI image, boot compatibility may vary"),
            .init(id: "22.04", title: "22.04 LTS", image: "ubuntu:22.04", description: "Generic Ubuntu OCI image, boot compatibility may vary"),
            .init(id: "latest", title: "Latest", image: "ubuntu:latest", description: "Generic Ubuntu OCI image, boot compatibility may vary"),
        ]),
        .init(id: "debian", title: "Debian", versions: [
            .init(id: "12", title: "12 Bookworm", image: "debian:12", description: "Generic Debian OCI image, boot compatibility may vary"),
            .init(id: "11", title: "11 Bullseye", image: "debian:11", description: "Generic Debian OCI image, boot compatibility may vary"),
            .init(id: "latest", title: "Latest", image: "debian:latest", description: "Generic Debian OCI image, boot compatibility may vary"),
        ]),
        .init(id: "fedora", title: "Fedora", versions: [
            .init(id: "42", title: "42", image: "fedora:42", description: "Generic Fedora OCI image, boot compatibility may vary"),
            .init(id: "41", title: "41", image: "fedora:41", description: "Generic Fedora OCI image, boot compatibility may vary"),
            .init(id: "latest", title: "Latest", image: "fedora:latest", description: "Generic Fedora OCI image, boot compatibility may vary"),
        ]),
        .init(id: "arch", title: "Arch Linux", versions: [
            .init(id: "latest", title: "Latest", image: "archlinux:latest", description: "Generic Arch OCI image, boot compatibility may vary"),
        ]),
        .init(id: "nixos", title: "NixOS", versions: [
            .init(id: "latest", title: "Latest", image: "nixos/nix:latest", description: "Generic Nix OCI image, boot compatibility may vary"),
        ]),
        .init(id: "opensuse", title: "openSUSE", versions: [
            .init(id: "tumbleweed", title: "Tumbleweed", image: "opensuse/tumbleweed:latest", description: "Generic openSUSE OCI image, boot compatibility may vary"),
        ]),
        .init(id: "rocky", title: "Rocky Linux", versions: [
            .init(id: "9", title: "9", image: "rockylinux:9", description: "Generic Rocky OCI image, boot compatibility may vary"),
            .init(id: "8", title: "8", image: "rockylinux:8", description: "Generic Rocky OCI image, boot compatibility may vary"),
        ]),
        .init(id: "oracle", title: "Oracle Linux", versions: [
            .init(id: "9", title: "9", image: "oraclelinux:9", description: "Generic Oracle Linux OCI image, boot compatibility may vary"),
            .init(id: "8", title: "8", image: "oraclelinux:8", description: "Generic Oracle Linux OCI image, boot compatibility may vary"),
        ]),
        .init(id: "openeuler", title: "openEuler", versions: [
            .init(id: "24.03", title: "24.03", image: "openeuler/openeuler:24.03", description: "Generic openEuler OCI image, boot compatibility may vary"),
            .init(id: "22.03", title: "22.03", image: "openeuler/openeuler:22.03", description: "Generic openEuler OCI image, boot compatibility may vary"),
        ]),
    ]

    private static let machineHomeMountOptions: [MachineHomeMountOption] = [
        .init(value: "", title: "Automatic", description: "Use the Apple container default home folder behavior"),
        .init(value: "rw", title: "Read & Write", description: "Mount your macOS home folder with write access"),
        .init(value: "ro", title: "Read Only", description: "Mount your macOS home folder without write access"),
        .init(value: "none", title: "Disabled", description: "Do not mount your macOS home folder"),
    ]

    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @Binding var selectedMachine: Machine?
    var createRequestID: Int = 0
    @State private var machines: [Machine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var showSetSheet = false
    @State private var newMachine = MachineConfig()
    @State private var outputTitle = ""
    @State private var outputText = ""
    @State private var showOutputSheet = false
    @State private var machineCPUs = 2
    @State private var machineMemory = "2G"
    @State private var machineHomeMount = "rw"
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var machineToDelete: Machine?
    @State private var selectedMachineDistributionID = "custom"
    @State private var selectedMachineVersionID = "custom"
    @State private var isCreatingMachine = false
    @State private var machineCreationStatus = "Preparing machine..."
    @State private var machineCreationLog = ""
    @State private var machineCreateInlineError: String?
    @State private var showMachineImageBuildSheet = false
    @State private var machineBuildContext = "."
    @State private var machineBuildFile = "Containerfile"
    @State private var machineBuildTag = "machine-ubuntu:24.04"
    @State private var machineBuildPlatform = "linux/arm64"
    @State private var machineBuildDNS = "8.8.8.8"
    @State private var isBuildingMachineImage = false
    @State private var machineImageBuildError: String?
    @State private var machineTemplateActionMessage: String?
    @State private var machineImageBuildStatus = "Preparing build..."
    @State private var machineImageBuildLog = ""
    @AppStorage(Self.lastBuiltMachineImageReferenceKey) private var lastBuiltMachineImageReference = ""
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue
    @State private var pendingMachineIDs: Set<String> = []

    private let cliBackend = CLIBackend()

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: language.localized("Machines"),
                subtitle: "\(machines.count) \(language.localized("machines"))",
                leadingAccessory: nil,
                leadingInset: showsSidebarToggle ? AppTheme.windowControlsClearance : 0
            ) {
                headerActions
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(language.localized("Retry")) {
                        Task { await loadMachines() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if machines.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "desktopcomputer")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No machines"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredMachines.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No matching machines"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredMachines) { machine in
                            MachineRowView(
                                machine: machine,
                                isSelected: selectedMachine?.id == machine.id,
                                isPending: pendingMachineIDs.contains(machine.id),
                                onStart: { Task { await startMachine(machine) } },
                                onStop: { Task { await stopMachine(machine) } },
                                onDelete: { machineToDelete = machine }
                            )
                            .onTapGesture {
                                selectedMachine = machine
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $showCreateSheet) {
            createMachineSheet
        }
        .sheet(isPresented: $showOutputSheet) {
            InspectOutputSheet(title: outputTitle, output: outputText)
        }
        .confirmationDialog(
            "Delete machine \"\(machineToDelete?.name ?? "")\"?",
            isPresented: .init(
                get: { machineToDelete != nil },
                set: { if !$0 { machineToDelete = nil } }
            )
        ) {
            Button(language.localized("Delete"), role: .destructive) {
                if let m = machineToDelete {
                    Task { await deleteMachine(m) }
                }
                machineToDelete = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                machineToDelete = nil
            }
        } message: {
            Text(language.localized("This action cannot be undone."))
        }
        .sheet(isPresented: $showSetSheet) {
            setMachineSheet
        }
        .sheet(isPresented: $showMachineImageBuildSheet) {
            machineImageBuildSheet
        }
        .task {
            await loadMachines()
        }
        .onChange(of: createRequestID) { _, newValue in
            guard newValue > 0 else { return }
            beginCreateMachine()
        }
    }

    private var filteredMachines: [Machine] {
        guard !searchText.isEmpty else { return machines }
        return machines.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.image.localizedCaseInsensitiveContains(searchText) ||
            $0.status.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            fullHeaderActions
            compactHeaderActions
            minimalHeaderActions
        }
    }

    private var fullHeaderActions: some View {
        HStack(spacing: 8) {
            buildMachineImageButton
            searchToggle(width: 110)
            newMachineButton
        }
    }

    private var compactHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 88)
            newMachineButton
            overflowMenu
        }
    }

    private var minimalHeaderActions: some View {
        HStack(spacing: 8) {
            newMachineButton
            overflowMenu
        }
    }

    private var buildMachineImageButton: some View {
        HeaderCircleButton(
            systemName: "hammer",
            action: openMachineImageBuildSheet,
            helpText: language.localized("Build machine image")
        )
    }

    private var newMachineButton: some View {
        HeaderCircleButton(
            systemName: "plus",
            action: beginCreateMachine,
            helpText: language.localized("New Machine")
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: language.localized("More actions")) {
            searchMenuActions
            Divider()
            Button(language.localized("Build Machine Image")) {
                openMachineImageBuildSheet()
            }

            Button(language.localized("Inspect Selected Machine")) {
                if let selectedMachine {
                    Task { await inspectMachine(selectedMachine) }
                }
            }
            .disabled(selectedMachine == nil)

            Button(language.localized("Show Selected Machine Logs")) {
                if let selectedMachine {
                    Task { await machineLogs(selectedMachine) }
                }
            }
            .disabled(selectedMachine == nil)

            Button(language.localized("Configure Selected Machine")) {
                openSelectedMachineSettings()
            }
            .disabled(selectedMachine == nil)

            Button(language.localized("Set Selected as Default")) {
                if let selectedMachine {
                    Task { await setDefaultMachine(selectedMachine) }
                }
            }
            .disabled(selectedMachine == nil)
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(language.localized(isSearchExpanded ? "Hide Search" : "Search")) {
                isSearchExpanded.toggle()
            }

            if !searchText.isEmpty {
                Button(language.localized("Clear Search")) {
                    searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $searchText,
            isExpanded: $isSearchExpanded,
            placeholder: language.localized("Search"),
            width: width
        )
    }

    private var createMachineSheet: some View {
        Form {
            Section(language.localized("Machine")) {
                TextField(language.localized("Machine name"), text: $newMachine.name)
            }

            Section {
                if !lastBuiltMachineImageReference.isEmpty {
                    LabeledContent(language.localized("Recent build")) {
                        Text(lastBuiltMachineImageReference)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    Button(language.localized("Use Recent Build")) {
                        newMachine.image = lastBuiltMachineImageReference
                        syncSelectedMachineSelection()
                    }
                    .buttonStyle(.bordered)
                }

                Button(language.localized("Build Machine Image...")) {
                    prepareMachineImageBuildDefaults()
                    showMachineImageBuildSheet = true
                }
                .buttonStyle(.bordered)

                Picker(language.localized("Distribution"), selection: $selectedMachineDistributionID) {
                    ForEach(Self.machineDistributions) { distribution in
                        Text(distribution.title).tag(distribution.id)
                    }
                    Text(language.localized("Custom")).tag("custom")
                }
                .pickerStyle(.menu)

                if let selectedDistribution {
                    Picker(language.localized("Version"), selection: $selectedMachineVersionID) {
                        ForEach(selectedDistribution.versions) { version in
                            Text(version.title).tag(version.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let selectedVersion {
                    LabeledContent(language.localized("Preset")) {
                        Text(selectedVersion.image)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    LabeledContent(language.localized("Description")) {
                        Text(selectedVersion.description)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField(language.localized("Image reference"), text: $newMachine.image)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text(language.localized("Image"))
            } footer: {
                Text(language.localized("Choose a preset image or enter any OCI reference supported by Apple container. Generic distro images may still fail to boot as machines if they do not provide the init process expected by Apple container, such as `/sbin/init`. A safer workflow is to build a machine-compatible image first from Images > Build image, then paste that image reference here."))
            }

            Section {
                Stepper(value: $newMachine.cpus, in: 1...16) {
                    LabeledContent("CPUs") {
                        Text("\(newMachine.cpus) \(language.localized("cores"))")
                            .foregroundStyle(.secondary)
                    }
                }
                TextField(language.localized("Memory (e.g., 2G, 4G)"), text: $newMachine.memory)
            } header: {
                Text(language.localized("Resources"))
            } footer: {
                Text(language.localized("The current `container machine create` CLI exposes CPU and memory settings only. Disk size is managed by the current machine/image defaults."))
            }

            Section {
                LabeledContent(language.localized("Target")) {
                    Text("linux/arm64")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent(language.localized("Selection")) {
                    Text(language.localized("Default platform"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(language.localized("Architecture"))
            } footer: {
                Text(language.localized("Apple container supports `--arch`, `--os`, and `--platform` for `machine create`. This view currently uses the default `linux/arm64` target until explicit platform controls are wired into the form."))
            }

            Section {
                Picker(language.localized("Home folder mount"), selection: $newMachine.homeMount) {
                    ForEach(Self.machineHomeMountOptions) { option in
                        Text(option.title).tag(option.value)
                    }
                }
                .pickerStyle(.menu)

                if let selectedHomeMountOption {
                    Text(selectedHomeMountOption.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Toggle(language.localized("Set as default machine"), isOn: $newMachine.setDefault)
                Toggle(language.localized("Create without booting"), isOn: $newMachine.noBoot)
            } header: {
                Text(language.localized("Advanced"))
            } footer: {
                Text(language.localized("Advanced options map directly to `--home-mount`, `--set-default`, and `--no-boot`."))
            }

            if isCreatingMachine || !machineCreationLog.isEmpty || machineCreateInlineError != nil {
                Section(language.localized("Progress")) {
                    HStack(spacing: 10) {
                        if isCreatingMachine {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(machineCreationStatus)
                            .font(.system(size: 13, weight: .medium))
                    }

                    if let machineCreateInlineError {
                        Text(machineCreateInlineError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ScrollView {
                        Text(machineCreationLog.isEmpty ? language.localized("Waiting for output...") : machineCreationLog)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    }
                    .frame(minHeight: 140, maxHeight: 220)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            syncSelectedMachineSelection()
        }
        .onChange(of: selectedMachineDistributionID) { _, newValue in
            guard let distribution = Self.machineDistributions.first(where: { $0.id == newValue }),
                  let firstVersion = distribution.versions.first
            else { return }
            selectedMachineVersionID = firstVersion.id
            newMachine.image = firstVersion.image
        }
        .onChange(of: selectedMachineVersionID) { _, newValue in
            guard let version = selectedDistribution?.versions.first(where: { $0.id == newValue }) else { return }
            newMachine.image = version.image
        }
        .onChange(of: newMachine.image) { _, _ in
            syncSelectedMachineSelection()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) {
                    showCreateSheet = false
                    newMachine = MachineConfig()
                    resetMachineCreateState()
                }
                .disabled(isCreatingMachine)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Create")) {
                    Task {
                        let config = normalizedMachineConfig()
                        if await createMachine(config) {
                            showCreateSheet = false
                            newMachine = MachineConfig()
                            resetMachineCreateState()
                        }
                    }
                }
                .disabled(!canCreateMachine)
            }
        }
    }

    private var machineImageBuildSheet: some View {
        Form {
            Section {
                TextField(language.localized("Context directory"), text: $machineBuildContext)
                TextField(language.localized("Dockerfile/Containerfile path"), text: $machineBuildFile)
                TextField(language.localized("Tag"), text: $machineBuildTag)
                TextField(language.localized("Platform"), text: $machineBuildPlatform)
                TextField(language.localized("DNS nameserver"), text: $machineBuildDNS)
            } header: {
                Text(language.localized("Build Machine Image"))
            } footer: {
                Text(language.localized("This follows the tutorial workflow: build a machine-oriented image first, then create a machine from the resulting tag."))
            }

            Section {
                HStack(spacing: 10) {
                    Button(language.localized("Copy Template")) {
                        copyMachineStarterTemplate()
                    }
                    .buttonStyle(.bordered)

                    Button(language.localized("Write Template File")) {
                        writeMachineStarterTemplate()
                    }
                    .buttonStyle(.bordered)
                }

                ScrollView {
                    Text(Self.machineStarterTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 180, maxHeight: 220)
            } header: {
                Text(language.localized("Starter Containerfile"))
            } footer: {
                Text(language.localized("Use a base image that provides `/sbin/init`, reset machine-id files, and boot into a non-GUI target."))
            }

            if isBuildingMachineImage || machineImageBuildError != nil || machineTemplateActionMessage != nil || !machineImageBuildLog.isEmpty {
                Section(language.localized("Build Status")) {
                    if isBuildingMachineImage {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text(machineImageBuildStatus)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }

                    if let machineImageBuildError {
                        Text(machineImageBuildError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let machineTemplateActionMessage {
                        Text(machineTemplateActionMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !machineImageBuildLog.isEmpty {
                        ScrollView {
                            Text(machineImageBuildLog)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .frame(minHeight: 120, maxHeight: 180)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) {
                    showMachineImageBuildSheet = false
                    machineImageBuildError = nil
                }
                .disabled(isBuildingMachineImage)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Build")) {
                    Task { await buildMachineImageFromCreateFlow() }
                }
                .disabled(
                    machineBuildContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    machineBuildTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    isBuildingMachineImage
                )
            }
        }
    }

    private var setMachineSheet: some View {
        Form {
            Section(language.localized("Machine Configuration")) {
                Stepper("CPUs: \(machineCPUs)", value: $machineCPUs, in: 1...16)
                TextField(language.localized("Memory"), text: $machineMemory)
                Picker(language.localized("Home Mount"), selection: $machineHomeMount) {
                    Text(language.localized("Read/Write")).tag("rw")
                    Text(language.localized("Read Only")).tag("ro")
                    Text(language.localized("None")).tag("none")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 240)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) { showSetSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Apply")) {
                    Task { await setMachineConfig() }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadMachines(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            machines = try await cliBackend.listMachines()
        } catch {
            errorMessage = error.localizedDescription
        }
        if showLoading {
            isLoading = false
        }
    }

    private func buildMachineImageFromCreateFlow() async {
        isBuildingMachineImage = true
        machineImageBuildError = nil
        machineTemplateActionMessage = nil
        machineImageBuildLog = ""
        machineImageBuildStatus = "Building machine image..."

        let contextDirectory = machineBuildContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let dockerfilePath = machineBuildFile.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = machineBuildTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let platform = machineBuildPlatform.trimmingCharacters(in: .whitespacesAndNewlines)
        let dns = machineBuildDNS.trimmingCharacters(in: .whitespacesAndNewlines)

        let options = ImageBuildOptions(
            contextDirectory: contextDirectory,
            dockerfilePath: dockerfilePath.isEmpty ? nil : dockerfilePath,
            tags: tag.isEmpty ? [] : [tag],
            platform: platform.isEmpty ? nil : platform,
            dns: dns.isEmpty ? nil : dns,
            buildArgs: [:],
            noCache: false,
            pull: false
        )

        do {
            try await cliBackend.buildImage(options: options) { chunk in
                Task { @MainActor in
                    machineImageBuildLog += chunk
                    updateMachineImageBuildStatus(from: chunk)
                }
            }
            if let firstTag = options.tags.first, !firstTag.isEmpty {
                lastBuiltMachineImageReference = firstTag
                newMachine.image = firstTag
                syncSelectedMachineSelection()
            }
            machineImageBuildStatus = "Build completed"
            isBuildingMachineImage = false
            showMachineImageBuildSheet = false
        } catch {
            machineImageBuildError = ContainerServiceErrorPresenter.machineImageBuildMessage(
                for: error,
                buildLog: machineImageBuildLog,
                dockerfilePath: options.dockerfilePath,
                contextDirectory: options.contextDirectory
            )
            machineImageBuildStatus = "Build failed"
            isBuildingMachineImage = false
        }
    }

    private func createMachine(_ config: MachineConfig) async -> Bool {
        isCreatingMachine = true
        machineCreateInlineError = nil
        machineCreationLog = ""
        machineCreationStatus = "Validating image..."

        do {
            switch await validateMachineImageReference(config.image) {
            case .missingInit:
                let message = "创建前预检查失败。\n\n当前镜像内未找到 `/sbin/init`，它不是可直接用于 Apple container machine 的镜像。请先使用 `Build Machine Image...` 生成兼容镜像，或者确认你填写的镜像引用确实指向刚刚构建的 machine image。"
                machineCreateInlineError = message
                machineCreationStatus = "Image validation failed"
                errorMessage = message
                isCreatingMachine = false
                return false
            case .inconclusive(let detail):
                if let detail, !detail.isEmpty {
                    machineCreationLog += "Image preflight check was inconclusive: \(detail)\n"
                }
            case .valid:
                break
            }

            machineCreationStatus = "Creating machine..."
            let createConfig: MachineConfig = {
                guard !config.noBoot else { return config }
                var bootlessConfig = config
                bootlessConfig.noBoot = true
                return bootlessConfig
            }()

            try await cliBackend.createMachine(config: createConfig) { chunk in
                Task { @MainActor in
                    machineCreationLog += chunk
                    updateMachineCreationStatus(from: chunk)
                }
            }

            if !config.noBoot {
                machineCreationStatus = "Booting machine..."
                machineCreationLog += "\nBooting machine...\n"
                try await cliBackend.startMachine(id: config.name)
            }

            await loadMachines()
            machineCreationStatus = config.noBoot ? "Machine created" : "Machine created and booted"
            isCreatingMachine = false
            return true
        } catch {
            await loadMachines()

            let machineWasCreated = machines.contains { machine in
                machine.id == config.name || machine.name == config.name
            }

            if machineWasCreated && !config.noBoot {
                let bootLogs = try? await cliBackend.machineLogs(id: config.name, follow: false, tail: 120, boot: true)
                let runtimeLogs = try? await cliBackend.machineLogs(id: config.name, follow: false, tail: 40, boot: false)
                let diagnostic = machineBootErrorMessage(
                    error: error,
                    bootLogs: bootLogs,
                    runtimeLogs: runtimeLogs,
                    failureHeadline: "Machine image was created, but boot failed."
                )
                let bootFailureMessage = diagnostic + "\n\nTry starting it again from the list, or recreate it with \"Create without booting\" enabled."
                machineCreateInlineError = bootFailureMessage
                machineCreationStatus = "Boot failed after create"
                errorMessage = bootFailureMessage
            } else {
                machineCreateInlineError = error.localizedDescription
                machineCreationStatus = "Create failed"
                errorMessage = error.localizedDescription
            }
            isCreatingMachine = false
            return false
        }
    }

    private func validateMachineImageReference(_ reference: String) async -> MachineImageValidationResult {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            return .inconclusive("Image reference is empty.")
        }

        let shellCommand = """
        if [ -x /sbin/init ] || [ -e /sbin/init ]; then
            echo \(Self.machineInitCheckSuccessMarker)
        else
            echo \(Self.machineInitCheckMissingMarker)
            exit 42
        fi
        """

        let config = ContainerConfig(
            image: trimmedReference,
            autoRemove: true
        )

        do {
            let output = try await cliBackend.runContainer(
                config: config,
                command: ["/bin/sh", "-lc", shellCommand]
            )

            if output.contains(Self.machineInitCheckSuccessMarker) {
                return .valid
            }
            if output.contains(Self.machineInitCheckMissingMarker) {
                return .missingInit
            }
            return .inconclusive(nil)
        } catch {
            let message = String(describing: error) + "\n" + error.localizedDescription
            if message.contains(Self.machineInitCheckMissingMarker) {
                return .missingInit
            }
            if message.localizedCaseInsensitiveContains("Timed out") {
                return .inconclusive("Timed out while probing the image.")
            }
            if message.localizedCaseInsensitiveContains("/bin/sh") && message.localizedCaseInsensitiveContains("not found") {
                return .inconclusive("The image does not expose `/bin/sh`, so the preflight check could not verify `/sbin/init`.")
            }
            return .inconclusive(message)
        }
    }

    private var selectedDistribution: MachineDistribution? {
        Self.machineDistributions.first(where: { $0.id == selectedMachineDistributionID })
    }

    private var selectedVersion: MachineImageVersion? {
        selectedDistribution?.versions.first(where: { $0.id == selectedMachineVersionID })
    }

    private var selectedHomeMountOption: MachineHomeMountOption? {
        Self.machineHomeMountOptions.first(where: { $0.value == newMachine.homeMount })
    }

    private var canCreateMachine: Bool {
        !newMachine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newMachine.image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isCreatingMachine
    }

    private func prepareMachineImageBuildDefaults() {
        if machineBuildContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            machineBuildContext = "."
        }
        if machineBuildFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            machineBuildFile = "Containerfile"
        }
        if machineBuildTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            machineBuildTag = "machine-ubuntu:24.04"
        }
        if machineBuildPlatform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            machineBuildPlatform = "linux/arm64"
        }
        if machineBuildDNS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            machineBuildDNS = "8.8.8.8"
        }
        machineImageBuildError = nil
        machineTemplateActionMessage = nil
        machineImageBuildStatus = "Preparing build..."
        machineImageBuildLog = ""
    }

    private func openMachineImageBuildSheet() {
        prepareMachineImageBuildDefaults()
        showMachineImageBuildSheet = true
    }

    private func openSelectedMachineSettings() {
        guard let selectedMachine else { return }
        machineCPUs = selectedMachine.cpus
        machineMemory = selectedMachine.memory
        showSetSheet = true
    }

    private func updateMachineImageBuildStatus(from chunk: String) {
        let normalized = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let lines = normalized
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let latestLine = lines.last else { return }

        if latestLine.localizedCaseInsensitiveContains("fetch") {
            machineImageBuildStatus = "Fetching base image..."
        } else if latestLine.localizedCaseInsensitiveContains("unpack") {
            machineImageBuildStatus = "Unpacking layers..."
        } else if latestLine.localizedCaseInsensitiveContains("step") ||
            latestLine.localizedCaseInsensitiveContains("run ") ||
            latestLine.localizedCaseInsensitiveContains("apt-get") {
            machineImageBuildStatus = "Running build steps..."
        } else {
            machineImageBuildStatus = latestLine
        }
    }

    private func copyMachineStarterTemplate() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(Self.machineStarterTemplate, forType: .string)
        machineTemplateActionMessage = "Starter Containerfile copied to clipboard."
    }

    private func writeMachineStarterTemplate() {
        machineImageBuildError = nil

        let contextDirectory = machineBuildContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let dockerfilePath = machineBuildFile.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !contextDirectory.isEmpty else {
            machineImageBuildError = "Context directory is required before writing the starter template."
            return
        }

        guard !dockerfilePath.isEmpty else {
            machineImageBuildError = "Dockerfile/Containerfile path is required before writing the starter template."
            return
        }

        let baseURL = URL(fileURLWithPath: NSString(string: contextDirectory).expandingTildeInPath)
        let fileURL = URL(fileURLWithPath: dockerfilePath, relativeTo: baseURL).standardizedFileURL

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try Self.machineStarterTemplate.write(to: fileURL, atomically: true, encoding: .utf8)
            machineTemplateActionMessage = "Starter template written to \(fileURL.path)."
        } catch {
            machineImageBuildError = "Failed to write starter template: \(error.localizedDescription)"
        }
    }

    private func beginCreateMachine() {
        newMachine = MachineConfig()
        if !lastBuiltMachineImageReference.isEmpty {
            newMachine.image = lastBuiltMachineImageReference
        }
        resetMachineCreateState()
        syncSelectedMachineSelection()
        showCreateSheet = true
    }

    private func syncSelectedMachineSelection() {
        if let distribution = Self.machineDistributions.first(where: { distribution in
            distribution.versions.contains(where: { $0.image == newMachine.image })
        }), let version = distribution.versions.first(where: { $0.image == newMachine.image }) {
            selectedMachineDistributionID = distribution.id
            selectedMachineVersionID = version.id
        } else {
            selectedMachineDistributionID = "custom"
            selectedMachineVersionID = "custom"
        }
    }

    private func resetMachineCreateState() {
        selectedMachineDistributionID = "custom"
        selectedMachineVersionID = "custom"
        isCreatingMachine = false
        machineCreationStatus = "Preparing machine..."
        machineCreationLog = ""
        machineCreateInlineError = nil
    }

    private func normalizedMachineConfig() -> MachineConfig {
        var config = newMachine
        config.name = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
        config.image = config.image.trimmingCharacters(in: .whitespacesAndNewlines)
        config.memory = config.memory.trimmingCharacters(in: .whitespacesAndNewlines)
        return config
    }

    private func updateMachineCreationStatus(from chunk: String) {
        let lines = chunk
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return }

        if lastLine.contains("Fetching image") {
            machineCreationStatus = "Fetching image..."
        } else if lastLine.contains("Unpacking image") {
            machineCreationStatus = "Unpacking image..."
        } else if lastLine.contains("Booting") || lastLine.contains("boot") {
            machineCreationStatus = "Booting machine..."
        } else {
            machineCreationStatus = lastLine
        }
    }

    private func startMachine(_ machine: Machine) async {
        guard !pendingMachineIDs.contains(machine.id) else { return }
        pendingMachineIDs.insert(machine.id)
        defer { pendingMachineIDs.remove(machine.id) }
        do {
            try await cliBackend.startMachine(id: machine.id)
            try await waitForMachine(id: machine.id) { $0?.status == .running }
            await loadMachines(showLoading: false)
        } catch {
            let bootLogs = try? await cliBackend.machineLogs(id: machine.id, follow: false, tail: 120, boot: true)
            let runtimeLogs = try? await cliBackend.machineLogs(id: machine.id, follow: false, tail: 40, boot: false)
            errorMessage = machineBootErrorMessage(
                error: error,
                bootLogs: bootLogs,
                runtimeLogs: runtimeLogs,
                failureHeadline: "启动虚拟机失败。"
            )
            await loadMachines(showLoading: false)
        }
    }

    private func machineBootErrorMessage(
        error: Error,
        bootLogs: String?,
        runtimeLogs: String?,
        failureHeadline: String
    ) -> String {
        let bootLogsText = bootLogs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let runtimeLogsText = runtimeLogs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combinedLogs = [runtimeLogsText, bootLogsText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if combinedLogs.localizedCaseInsensitiveContains("/sbin/init: not found") {
            var message = "\(failureHeadline)\n\n当前镜像不是可启动的 machine 镜像。Apple container 在 boot machine 时需要镜像内提供 init 进程，但当前镜像缺少 `/sbin/init`，因此 machine 会在启动后立即退出。"
            message += "\n\n建议：改用明确支持 machine boot 的镜像，或换成包含 init/systemd/openrc 等初始化进程的镜像。"
            if !runtimeLogsText.isEmpty {
                message += "\n\nRuntime logs:\n\(runtimeLogsText)"
            }
            if !bootLogsText.isEmpty {
                message += "\n\nBoot logs:\n\(bootLogsText)"
            }
            return message
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("Timed out waiting for machine"),
           combinedLogs.localizedCaseInsensitiveContains("managed process exit") {
            var message = "\(failureHeadline)\n\nMachine 没有在预期时间内进入 running。日志显示 guest 内部的受管进程已经退出，这通常意味着当前 machine 镜像的 init 配置不完整，或者 systemd/openrc 在启动阶段被某些 unit 卡住。"
            if !runtimeLogsText.isEmpty {
                message += "\n\nRuntime logs:\n\(runtimeLogsText)"
            }
            if !bootLogsText.isEmpty {
                message += "\n\nBoot logs:\n\(bootLogsText)"
            }
            return message
        }

        var message = "\(failureHeadline)\n\n\(error.localizedDescription)"
        if !runtimeLogsText.isEmpty {
            message += "\n\nRuntime logs:\n\(runtimeLogsText)"
        }
        if !bootLogsText.isEmpty {
            message += "\n\nBoot logs:\n\(bootLogsText)"
        }
        return message
    }

    private func stopMachine(_ machine: Machine) async {
        guard !pendingMachineIDs.contains(machine.id) else { return }
        pendingMachineIDs.insert(machine.id)
        defer { pendingMachineIDs.remove(machine.id) }
        do {
            try await cliBackend.stopMachine(id: machine.id)
            try await waitForMachine(id: machine.id) { found in
                guard let found else { return true }
                return found.status != .running
            }
            await loadMachines(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadMachines(showLoading: false)
        }
    }

    private func deleteMachine(_ machine: Machine) async {
        guard !pendingMachineIDs.contains(machine.id) else { return }
        pendingMachineIDs.insert(machine.id)
        defer { pendingMachineIDs.remove(machine.id) }
        do {
            try await cliBackend.removeMachine(id: machine.id)
            try await waitForMachine(id: machine.id) { $0 == nil }
            if selectedMachine?.id == machine.id {
                selectedMachine = nil
            }
            await loadMachines(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
            await loadMachines(showLoading: false)
        }
    }

    private func inspectMachine(_ machine: Machine) async {
        do {
            outputTitle = "Machine Inspect"
            outputText = try await cliBackend.inspectMachine(id: machine.id)
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func machineLogs(_ machine: Machine) async {
        do {
            outputTitle = "Machine Logs"
            outputText = try await cliBackend.machineLogs(id: machine.id, follow: false, tail: 200, boot: false)
            showOutputSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setDefaultMachine(_ machine: Machine) async {
        guard !pendingMachineIDs.contains(machine.id) else { return }
        pendingMachineIDs.insert(machine.id)
        defer { pendingMachineIDs.remove(machine.id) }
        do {
            try await cliBackend.setDefaultMachine(id: machine.id)
            await loadMachines(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setMachineConfig() async {
        guard let machine = selectedMachine else { return }
        do {
            try await cliBackend.setMachine(
                id: machine.id,
                cpus: machineCPUs,
                memory: machineMemory,
                homeMount: machineHomeMount
            )
            showSetSheet = false
            await loadMachines(showLoading: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func waitForMachine(
        id: String,
        timeoutSeconds: Double = 45,
        matches: (Machine?) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let latest = try await cliBackend.listMachines()
            machines = latest
            if matches(latest.first(where: { $0.id == id || $0.name == id })) {
                return
            }
            try await Task.sleep(for: .milliseconds(700))
        }
    }
}

#Preview {
    MachineListView(selectedMachine: .constant(nil))
}
