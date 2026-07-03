import SwiftUI

struct MachineDetailView: View {
    let machine: Machine
    let selectedTab: String

    @Environment(\.cliBackend) private var cliBackend
    @StateObject private var terminalSession: PersistentTerminalSession
    @State private var inspectOutput: String?
    @State private var isLoadingInspect = false
    @State private var inspectError: String?
    @State private var browserPath = "/"
    @State private var fileEntries: [ContainerFileEntry] = []
    @State private var isLoadingFiles = false
    @State private var fileBrowserError: String?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    init(machine: Machine, selectedTab: String) {
        self.machine = machine
        self.selectedTab = selectedTab
        self._terminalSession = StateObject(wrappedValue: PersistentTerminalSession(
            target: .machine(id: machine.id)
        ))
    }

    var body: some View {
        Group {
            switch selectedTab {
            case "Resources":
                resourcesView
            case "Terminal":
                terminalView
            case "Files":
                filesView
            case "Inspect":
                inspectView
            default:
                infoView
            }
        }
        .background(AppTheme.paneBackground)
        .task(id: machine.id) {
            await loadInspectDetails()
        }
        .task(id: selectedTab) {
            if selectedTab == "Files" {
                await loadMachineDirectory()
            }
        }
    }

    private var infoView: some View {
        Group {
            if isLoadingInspect && inspectOutput == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        InspectorSection(title: "Overview") {
                            InspectorCard {
                                InspectorRows(rows: [
                                    .init(label: "Name", value: machine.name),
                                    .init(label: "ID", value: machine.id, usesMonospacedFont: true),
                                    .init(label: "Status", value: machine.status.rawValue),
                                    .init(label: "IP Address", value: machine.ip, usesMonospacedFont: true),
                                    .init(label: "Image", value: machine.image, usesMonospacedFont: true),
                                    .init(label: "Created", value: machine.created),
                                ].filter(\.hasContent))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var resourcesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Resources") {
                    InspectorCard {
                        InspectorRows(rows: [
                            .init(label: "CPUs", value: "\(machine.cpus)"),
                            .init(label: "Memory", value: machine.memory),
                            .init(label: "Disk", value: machine.disk),
                            .init(label: "IP Address", value: machine.ip),
                        ].filter(\.hasContent))
                    }
                }

                if let inspectError {
                    InspectorSection(title: "Diagnostics") {
                        InspectorCard {
                            Text(inspectError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var terminalView: some View {
        NativeTerminalView(
            sessionTitle: language.localized("Machine Terminal"),
            sessionSubtitle: machine.name,
            prompt: "\(machine.name) %",
            placeholder: language.localized("Enter shell command"),
            isAvailable: machine.status == .running,
            unavailableTitle: language.localized("Machine is not running"),
            unavailableMessage: language.localized("Start the machine to access the terminal."),
            showsMacTerminalButton: true,
            session: terminalSession
        )
    }

    private var inspectView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Inspect") {
                    InspectorCard {
                        Text(inspectOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? inspectOutput! : "No inspect output available")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let inspectError {
                    InspectorSection(title: "Diagnostics") {
                        InspectorCard {
                            Text(inspectError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var filesView: some View {
        VStack(spacing: 0) {
            machineFileBrowserToolbar

            machineFileBrowserContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.paneBackground)
    }

    private var machineFileBrowserToolbar: some View {
        HStack(spacing: 8) {
            TextField(language.localized("Machine path"), text: $browserPath)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(AppTheme.fileBrowserBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .onSubmit {
                    Task { await loadMachineDirectory() }
                }

            Menu {
                ForEach(MachineFileQuickLocation.defaults) { location in
                    Button {
                        openMachinePath(location.path)
                    } label: {
                        Label(language.localized(location.title), systemImage: location.path == "/" ? "internaldrive" : "folder")
                    }
                }
            } label: {
                SwiftUI.Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(language.localized("Quick folders"))
            .disabled(isLoadingFiles || machine.status != .running)

            machineFileToolbarButton("arrow.up", help: language.localized("Parent folder")) {
                browserPath = parentPath(of: browserPath)
                Task { await loadMachineDirectory() }
            }
            .disabled(browserPath == "/" || isLoadingFiles || machine.status != .running)

            machineFileToolbarButton("arrow.clockwise", help: language.localized("Refresh")) {
                Task { await loadMachineDirectory() }
            }
            .disabled(isLoadingFiles || machine.status != .running)

            if isLoadingFiles, !fileEntries.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.paneBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var machineFileBrowserContent: some View {
        if machine.status != .running {
            machineFilesMessage(
                icon: "powerplug",
                title: language.localized("Machine is not running"),
                message: language.localized("Start the machine to browse files.")
            )
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if isLoadingFiles && fileEntries.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(language.localized("Loading files..."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.fileBrowserBackground)
        } else if let fileBrowserError {
            machineFilesMessage(
                icon: "exclamationmark.triangle",
                title: language.localized("Cannot load files"),
                message: fileBrowserError
            )
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if fileEntries.isEmpty {
            machineFilesMessage(
                icon: "folder",
                title: language.localized("Empty folder"),
                message: language.localized("No files in this directory.")
            )
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(fileEntries.enumerated()), id: \.element.id) { index, entry in
                            machineFileEntryRow(entry, rowIndex: index)
                        }
                    } header: {
                        machineFileBrowserHeader
                    }
                }
            }
            .background(AppTheme.fileBrowserBackground)
        }
    }

    private func machineFileToolbarButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private var machineFileBrowserHeader: some View {
        HStack(spacing: 10) {
            Text(language.localized("Name"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(language.localized("Date Modified"))
                .frame(width: 136, alignment: .leading)
            Text(language.localized("Size"))
                .frame(width: 86, alignment: .trailing)
            Text(language.localized("Kind"))
                .frame(width: 86, alignment: .leading)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.fileBrowserRowBackground)
    }

    private func machineFileEntryRow(_ entry: ContainerFileEntry, rowIndex: Int) -> some View {
        Button {
            let path = joinedPath(browserPath, entry.name)
            if entry.isDirectory {
                browserPath = path
                Task { await loadMachineDirectory() }
            }
        } label: {
            HStack(spacing: 10) {
                Group {
                    if entry.isDirectory {
                        SwiftUI.Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 10)

                SwiftUI.Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(entry.isDirectory ? Color.blue : .secondary)
                    .frame(width: 18)

                Text(entry.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.modified)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 136, alignment: .leading)

                Text(entry.isDirectory ? "--" : entry.size)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 86, alignment: .trailing)

                Text(language.localized(entry.kind))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 86, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(rowIndex.isMultiple(of: 2) ? AppTheme.fileBrowserRowBackground.opacity(0.72) : Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            machineFileEntryContextMenu(entry)
        }
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.45)
        }
    }

    @ViewBuilder
    private func machineFileEntryContextMenu(_ entry: ContainerFileEntry) -> some View {
        let path = joinedPath(browserPath, entry.name)
        if entry.isDirectory {
            Button {
                browserPath = path
                Task { await loadMachineDirectory() }
            } label: {
                Label(language.localized("Open Folder"), systemImage: "folder")
            }

            Button {
                openMachineDirectoryInTerminal(path)
            } label: {
                Label(language.localized("Open in Terminal"), systemImage: "terminal")
            }
        }

        Button {
            copyToClipboard(path)
        } label: {
            Label(language.localized("Copy Path"), systemImage: "doc.on.doc")
        }

        Button {
            copyToClipboard("machine://\(machine.id)\(path)")
        } label: {
            Label(language.localized("Copy Machine Reference"), systemImage: "desktopcomputer")
        }

        Divider()

        Button {
            Task { await loadMachineDirectory() }
        } label: {
            Label(language.localized("Refresh"), systemImage: "arrow.clockwise")
        }
    }

    private func machineFilesMessage(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SwiftUI.Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.fileBrowserRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func loadInspectDetails() async {
        isLoadingInspect = true
        inspectError = nil

        do {
            inspectOutput = try await cliBackend.inspectMachine(id: machine.id)
        } catch {
            inspectOutput = nil
            inspectError = error.localizedDescription
        }

        isLoadingInspect = false
    }

    private func loadMachineDirectory() async {
        guard machine.status == .running else {
            fileEntries = []
            fileBrowserError = nil
            return
        }

        let path = normalizedPath(browserPath)
        browserPath = path
        isLoadingFiles = true
        fileBrowserError = nil
        defer { isLoadingFiles = false }

        do {
            fileEntries = try await cliBackend.listMachineDirectory(machineId: machine.id, path: path)
        } catch {
            fileEntries = []
            fileBrowserError = MachineFileBrowserErrorMessage.describe(error, path: path)
        }
    }

    private func openMachinePath(_ path: String) {
        browserPath = normalizedPath(path)
        Task { await loadMachineDirectory() }
    }

    private func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    private func parentPath(of path: String) -> String {
        let normalized = normalizedPath(path)
        guard normalized != "/" else { return "/" }
        let parent = URL(fileURLWithPath: normalized).deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    private func joinedPath(_ base: String, _ name: String) -> String {
        let normalized = normalizedPath(base)
        return normalized == "/" ? "/\(name)" : "\(normalized)/\(name)"
    }

    private func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openMachineDirectoryInTerminal(_ path: String) {
        terminalSession.activateIfNeeded()
        terminalSession.appendLocalEcho("\n# cd \(path)\n")
        Task {
            do {
                try await terminalSession.send(command: "cd \(shellQuote(path)) && pwd")
            } catch {
                terminalSession.appendLocalEcho("Error: \(error.localizedDescription)\n")
            }
        }
    }

    private func shellQuote(_ value: String) -> String {
        let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
        if value.rangeOfCharacter(from: safeCharacters.inverted) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

}

#Preview {
    MachineDetailView(machine: Machine(
        id: "abc123",
        name: "my-machine",
        status: .running,
        image: "ubuntu:latest",
        cpus: 2,
        memory: "2g",
        disk: "20g",
        ip: "192.168.64.2"
    ), selectedTab: "Info")
}
