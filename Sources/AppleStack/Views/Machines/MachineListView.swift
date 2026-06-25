import AppKit
import SwiftUI

struct MachineListView: View {
    private struct MachineHomeMountOption: Identifiable {
        let value: String
        let title: String
        let description: String

        var id: String { value }
    }

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
    @State private var selectedMachineTemplateID = MachineSystemTemplate.recommended.id
    @State private var selectedMachineResourcePresetID = MachineResourcePreset.standard.id
    @State private var isCreatingMachine = false
    @State private var machineCreationStatus = "Preparing machine..."
    @State private var machineCreationLog = ""
    @State private var machineCreateInlineError: String?
    @State private var showMachineAdvancedOptions = false
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
            Section {
                Picker(language.localized("System template"), selection: $selectedMachineTemplateID) {
                    ForEach(MachineSystemTemplate.all) { template in
                        Text(language.localized(template.title)).tag(template.id)
                    }
                }
                .pickerStyle(.menu)

                if let selectedMachineTemplate {
                    LabeledContent(language.localized("Best for")) {
                        Text(language.localized(selectedMachineTemplate.summary))
                            .foregroundStyle(.secondary)
                    }
                    if let badge = selectedMachineTemplate.badge {
                        LabeledContent(language.localized("Tag")) {
                            Text(language.localized(badge))
                                .foregroundStyle(.green)
                        }
                    }
                }
            } header: {
                Text(language.localized("Choose a system"))
            } footer: {
                Text(language.localized("AppleStack prepares the selected Linux system automatically."))
            }

            Section(language.localized("Machine")) {
                TextField(language.localized("Machine name"), text: $newMachine.name)
            }

            Section {
                Picker(language.localized("Size"), selection: $selectedMachineResourcePresetID) {
                    ForEach(MachineResourcePreset.all) { preset in
                        Text("\(language.localized(preset.title)) · \(preset.summary)").tag(preset.id)
                    }
                }
                .pickerStyle(.menu)

                if let selectedMachineResourcePreset {
                    LabeledContent(language.localized("CPU")) {
                        Text("\(selectedMachineResourcePreset.cpus) \(language.localized("cores"))")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent(language.localized("Memory")) {
                        Text(selectedMachineResourcePreset.memory)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(language.localized("Configuration"))
            } footer: {
                Text(language.localized("Standard is recommended for most local development work."))
            }

            Section(language.localized("Advanced Options")) {
                Toggle(language.localized("Show advanced options"), isOn: $showMachineAdvancedOptions)
            }

            if showMachineAdvancedOptions {
                Section {
                    Picker(language.localized("Home folder access"), selection: $newMachine.homeMount) {
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
                    Toggle(language.localized("Create but do not start yet"), isOn: $newMachine.noBoot)
                } header: {
                    Text(language.localized("Advanced"))
                } footer: {
                    Text(language.localized("Leave these unchanged unless you know you need different access or startup behavior."))
                }
            }

            if isCreatingMachine || !machineCreationLog.isEmpty || machineCreateInlineError != nil {
                Section(language.localized("Progress")) {
                    HStack(spacing: 10) {
                        if isCreatingMachine {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(language.localized(machineCreationStatus))
                            .font(.system(size: 13, weight: .medium))
                    }

                    if let machineCreateInlineError {
                        Text(machineCreateInlineError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isCreatingMachine {
                        Text(language.localized("You can leave this window open while AppleStack prepares and starts the machine."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            applySelectedMachineTemplate()
            applySelectedResourcePreset()
        }
        .onChange(of: selectedMachineTemplateID) { _, _ in
            applySelectedMachineTemplate()
        }
        .onChange(of: selectedMachineResourcePresetID) { _, _ in
            applySelectedResourcePreset()
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
                        guard !config.name.isEmpty else {
                            machineCreateInlineError = language.localized("Please enter a machine name.")
                            machineCreationStatus = "Create failed"
                            return
                        }
                        if await createMachine(config, template: resolvedMachineTemplate) {
                            showCreateSheet = false
                            newMachine = MachineConfig()
                            resetMachineCreateState()
                        }
                    }
                }
                .disabled(isCreatingMachine)
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

    private func createMachine(_ config: MachineConfig, template: MachineSystemTemplate) async -> Bool {
        isCreatingMachine = true
        machineCreateInlineError = nil
        machineCreationLog = ""
        machineCreationStatus = "Preparing system template..."
        var didStartCreateCommand = false

        do {
            try await prepareSystemTemplateIfNeeded(template)

            machineCreationStatus = "Creating virtual machine..."
            let createConfig: MachineConfig = {
                guard !config.noBoot else { return config }
                var bootlessConfig = config
                bootlessConfig.noBoot = true
                return bootlessConfig
            }()

            didStartCreateCommand = true
            try await cliBackend.createMachine(config: createConfig) { chunk in
                Task { @MainActor in
                    machineCreationLog += chunk
                    updateMachineCreationStatus(from: chunk)
                }
            }

            if !config.noBoot {
                machineCreationStatus = "Starting virtual machine..."
                try await cliBackend.startMachine(id: config.name)
            }

            await loadMachines()
            machineCreationStatus = config.noBoot ? "Virtual machine created" : "Virtual machine is ready"
            isCreatingMachine = false
            return true
        } catch {
            await loadMachines()

            let machineWasCreated = machines.contains { machine in
                machine.id == config.name || machine.name == config.name
            }

            if !didStartCreateCommand {
                let message = "系统模板准备失败。请检查网络连接和 Apple container 是否正常运行后重试。"
                machineCreateInlineError = message
                machineCreationStatus = "System template failed"
                errorMessage = message
            } else if machineWasCreated && !config.noBoot {
                let bootLogs = try? await cliBackend.machineLogs(id: config.name, follow: false, tail: 120, boot: true)
                let runtimeLogs = try? await cliBackend.machineLogs(id: config.name, follow: false, tail: 40, boot: false)
                let diagnostic = machineBootErrorMessage(
                    error: error,
                    bootLogs: bootLogs,
                    runtimeLogs: runtimeLogs,
                    failureHeadline: "虚拟机已创建，但启动失败。"
                )
                let bootFailureMessage = diagnostic + "\n\n你可以从列表里再次启动，或重新创建时打开“创建后暂不启动”。"
                machineCreateInlineError = bootFailureMessage
                machineCreationStatus = "Start failed after create"
                errorMessage = bootFailureMessage
            } else {
                let message = "创建失败。请确认 Apple container 正常运行，然后重试。"
                machineCreateInlineError = message
                machineCreationStatus = "Create failed"
                errorMessage = message
            }
            isCreatingMachine = false
            return false
        }
    }

    private func prepareSystemTemplateIfNeeded(_ template: MachineSystemTemplate) async throws {
        if (try? await cliBackend.inspectImages(references: [template.internalImageTag])) != nil {
            return
        }

        machineCreationStatus = "Preparing system components..."

        let templateDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleStackMachineTemplates", isDirectory: true)
            .appendingPathComponent(template.id, isDirectory: true)
        try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: true)

        let containerfileURL = templateDirectory.appendingPathComponent("Containerfile")
        try template.containerfile.write(to: containerfileURL, atomically: true, encoding: .utf8)

        let options = template.buildOptions(in: templateDirectory)

        try await cliBackend.buildImage(options: options) { chunk in
            Task { @MainActor in
                machineCreationLog += chunk
                updateSystemTemplateStatus(from: chunk)
            }
        }
    }

    private var selectedHomeMountOption: MachineHomeMountOption? {
        Self.machineHomeMountOptions.first(where: { $0.value == newMachine.homeMount })
    }

    private var selectedMachineTemplate: MachineSystemTemplate? {
        MachineSystemTemplate.all.first(where: { $0.id == selectedMachineTemplateID })
    }

    private var resolvedMachineTemplate: MachineSystemTemplate {
        selectedMachineTemplate ?? .recommended
    }

    private var selectedMachineResourcePreset: MachineResourcePreset? {
        MachineResourcePreset.all.first(where: { $0.id == selectedMachineResourcePresetID })
    }

    private var resolvedMachineResourcePreset: MachineResourcePreset {
        selectedMachineResourcePreset ?? .standard
    }

    private func openSelectedMachineSettings() {
        guard let selectedMachine else { return }
        machineCPUs = selectedMachine.cpus
        machineMemory = selectedMachine.memory
        showSetSheet = true
    }

    private func beginCreateMachine() {
        resetMachineCreateState()
        newMachine = MachineConfig(
            name: resolvedMachineTemplate.defaultMachineName,
            image: resolvedMachineTemplate.internalImageTag,
            cpus: resolvedMachineResourcePreset.cpus,
            memory: resolvedMachineResourcePreset.memory,
            homeMount: "rw",
            noBoot: false
        )
        showCreateSheet = true
    }

    private func applySelectedMachineTemplate() {
        let template = resolvedMachineTemplate
        let existingDefaultNames = Set(MachineSystemTemplate.all.map(\.defaultMachineName))
        let currentName = newMachine.name.trimmingCharacters(in: .whitespacesAndNewlines)

        newMachine.image = template.internalImageTag
        if currentName.isEmpty || existingDefaultNames.contains(currentName) {
            newMachine.name = template.defaultMachineName
        }
    }

    private func applySelectedResourcePreset() {
        let resources = resolvedMachineResourcePreset
        newMachine.cpus = resources.cpus
        newMachine.memory = resources.memory
    }

    private func resetMachineCreateState() {
        selectedMachineTemplateID = MachineSystemTemplate.recommended.id
        selectedMachineResourcePresetID = MachineResourcePreset.standard.id
        isCreatingMachine = false
        machineCreationStatus = "Preparing machine..."
        machineCreationLog = ""
        machineCreateInlineError = nil
        showMachineAdvancedOptions = false
    }

    private func normalizedMachineConfig() -> MachineConfig {
        MachineConfig.quickCreate(
            name: newMachine.name.trimmingCharacters(in: .whitespacesAndNewlines),
            template: resolvedMachineTemplate,
            resources: resolvedMachineResourcePreset,
            homeMount: newMachine.homeMount,
            setDefault: newMachine.setDefault,
            startAfterCreate: !newMachine.noBoot
        )
    }

    private func updateMachineCreationStatus(from chunk: String) {
        let lines = chunk
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return }

        if lastLine.contains("Fetching image") {
            machineCreationStatus = "Preparing system components..."
        } else if lastLine.contains("Unpacking image") {
            machineCreationStatus = "Preparing system components..."
        } else if lastLine.contains("Booting") || lastLine.contains("boot") {
            machineCreationStatus = "Starting virtual machine..."
        } else {
            machineCreationStatus = "Creating virtual machine..."
        }
    }

    private func updateSystemTemplateStatus(from chunk: String) {
        let normalized = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        if normalized.localizedCaseInsensitiveContains("fetch") ||
            normalized.localizedCaseInsensitiveContains("pull") {
            machineCreationStatus = "Downloading system components..."
        } else {
            machineCreationStatus = "Preparing system components..."
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
        let rawBootLogsText = bootLogs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawRuntimeLogsText = runtimeLogs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combinedLogs = [rawRuntimeLogsText, rawBootLogsText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let bootLogsText = sanitizeMachineMessage(rawBootLogsText)
        let runtimeLogsText = sanitizeMachineMessage(rawRuntimeLogsText)

        let startupProgramPath = ["/sbin", "init"].joined(separator: "/")

        if combinedLogs.localizedCaseInsensitiveContains("\(startupProgramPath): not found") {
            var message = "\(failureHeadline)\n\n当前系统模板启动不完整，虚拟机已退出。建议重新选择系统模板后再创建一次。"
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
            var message = "\(failureHeadline)\n\n虚拟机没有在预期时间内进入运行状态。请稍后从列表再次启动，或换一个系统模板重新创建。"
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

    private func sanitizeMachineMessage(_ value: String) -> String {
        let startupProgramPath = ["/sbin", "init"].joined(separator: "/")
        let imageReferenceLabel = ["Image", "reference"].joined(separator: " ")
        let legacyMachineImageLabel = ["machine", "image"].joined(separator: " ")
        return value
            .replacingOccurrences(of: startupProgramPath, with: "系统启动程序")
            .replacingOccurrences(of: legacyMachineImageLabel, with: "system template", options: .caseInsensitive)
            .replacingOccurrences(of: imageReferenceLabel, with: "system template", options: .caseInsensitive)
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
