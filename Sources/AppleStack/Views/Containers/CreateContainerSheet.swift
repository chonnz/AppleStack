import SwiftUI

struct CreateContainerSheet: View {
    @Bindable var viewModel: ContainerListViewModel
    @State private var config = ContainerConfig()
    @State private var envKey = ""
    @State private var envValue = ""
    @State private var envFile = ""
    @State private var volumeSource = ""
    @State private var volumeDest = ""
    @State private var mountSpec = ""
    @State private var labelSpec = ""
    @State private var networkSpec = ""
    @State private var dnsSearch = ""
    @State private var dnsOption = ""
    @State private var ulimitSpec = ""
    @State private var tmpfsSpec = ""
    @State private var capAdd = ""
    @State private var capDrop = ""
    @State private var showAdvancedOptions = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Basic Settings")) {
                TextField(language.localized("Container Name"), text: $config.name)
                TextField(language.localized("Image (e.g., nginx:latest)"), text: $config.image)
                TextField(language.localized("Port Mapping (e.g., 8080:80)"), text: $config.ports)
            }

            Section(language.localized("Resources")) {
                Stepper("CPUs: \(config.cpus)", value: $config.cpus, in: 1...16)
                TextField(language.localized("Memory (e.g., 512m, 2g)"), text: $config.memory)
            }

            Section(language.localized("Advanced Options")) {
                Toggle(language.localized("Show advanced options"), isOn: $showAdvancedOptions)
            }

            if showAdvancedOptions {
                Section(language.localized("Network")) {
                    addArraySectionRow(language.localized("Network (name[,mac=...,mtu=...])"), text: $networkSpec) {
                        config.networks.append(networkSpec)
                        networkSpec = ""
                    }
                    arrayRows(config.networks, icon: "network") { value in
                        config.networks.removeAll { $0 == value }
                    }
                    TextField(language.localized("DNS (e.g., 8.8.8.8)"), text: $config.dns)
                    TextField(language.localized("DNS Domain"), text: $config.dnsDomain)
                    addArraySectionRow(language.localized("DNS Search Domain"), text: $dnsSearch) {
                        config.dnsSearch.append(dnsSearch)
                        dnsSearch = ""
                    }
                    arrayRows(config.dnsSearch, icon: "magnifyingglass") { value in
                        config.dnsSearch.removeAll { $0 == value }
                    }
                    addArraySectionRow(language.localized("DNS Option"), text: $dnsOption) {
                        config.dnsOptions.append(dnsOption)
                        dnsOption = ""
                    }
                    arrayRows(config.dnsOptions, icon: "slider.horizontal.3") { value in
                        config.dnsOptions.removeAll { $0 == value }
                    }
                    Toggle(language.localized("Do not configure DNS (--no-dns)"), isOn: $config.noDNS)
                }

                Section(language.localized("Environment Variables")) {
                    envVarsList
                    addEnvVarRow
                    addArraySectionRow(language.localized("Env file path"), text: $envFile) {
                        config.envFiles.append(envFile)
                        envFile = ""
                    }
                    arrayRows(config.envFiles, icon: "doc.text") { value in
                        config.envFiles.removeAll { $0 == value }
                    }
                }

                Section(language.localized("Volumes")) {
                    volumesList
                    addVolumeRow
                    addArraySectionRow(language.localized("Mount spec (type=bind,source=...,target=...,readonly)"), text: $mountSpec) {
                        config.mounts.append(mountSpec)
                        mountSpec = ""
                    }
                    arrayRows(config.mounts, icon: "shippingbox") { value in
                        config.mounts.removeAll { $0 == value }
                    }
                    addArraySectionRow(language.localized("tmpfs path"), text: $tmpfsSpec) {
                        config.tmpfs.append(tmpfsSpec)
                        tmpfsSpec = ""
                    }
                    arrayRows(config.tmpfs, icon: "memorychip") { value in
                        config.tmpfs.removeAll { $0 == value }
                    }
                    TextField(language.localized("Shared memory size (e.g., 1G)"), text: $config.shmSize)
                }

                Section(language.localized("Options")) {
                    Toggle(language.localized("Run in background (--detach)"), isOn: $config.detach)
                    Toggle(language.localized("Interactive mode (-i)"), isOn: $config.interactive)
                    Toggle(language.localized("Allocate TTY (-t)"), isOn: $config.tty)
                    Toggle(language.localized("Auto-remove (--rm)"), isOn: $config.autoRemove)
                }

                Section(language.localized("Process")) {
                    TextField(language.localized("Entrypoint"), text: $config.entrypoint)
                    TextField(language.localized("Working directory"), text: $config.workdir)
                    TextField(language.localized("User (name|uid[:gid])"), text: $config.user)
                    TextField("UID", text: $config.uid)
                    TextField("GID", text: $config.gid)
                    Toggle(language.localized("Use init process (--init)"), isOn: $config.initProcess)
                    TextField(language.localized("Init image"), text: $config.initImage)
                    addArraySectionRow(language.localized("Ulimit (type=soft[:hard])"), text: $ulimitSpec) {
                        config.ulimits.append(ulimitSpec)
                        ulimitSpec = ""
                    }
                    arrayRows(config.ulimits, icon: "speedometer") { value in
                        config.ulimits.removeAll { $0 == value }
                    }
                }

                Section(language.localized("Platform & Runtime")) {
                    TextField(language.localized("Platform (e.g., linux/arm64)"), text: $config.platform)
                    TextField(language.localized("Architecture"), text: $config.arch)
                    TextField(language.localized("OS"), text: $config.os)
                    TextField(language.localized("Kernel path"), text: $config.kernel)
                    TextField(language.localized("Runtime handler"), text: $config.runtime)
                    TextField(language.localized("Registry scheme (auto/http/https)"), text: $config.scheme)
                    TextField(language.localized("Max concurrent downloads"), text: $config.maxConcurrentDownloads)
                }

                Section(language.localized("Capabilities & VM")) {
                    Toggle(language.localized("Read-only root filesystem"), isOn: $config.readOnly)
                    Toggle(language.localized("Enable Rosetta"), isOn: $config.rosetta)
                    Toggle(language.localized("Forward SSH agent"), isOn: $config.ssh)
                    Toggle(language.localized("Expose nested virtualization"), isOn: $config.virtualization)

                    addArraySectionRow(language.localized("Label (key=value)"), text: $labelSpec) {
                        config.labels.append(labelSpec)
                        labelSpec = ""
                    }
                    arrayRows(config.labels, icon: "tag") { value in
                        config.labels.removeAll { $0 == value }
                    }

                    addArraySectionRow(language.localized("Capability to add"), text: $capAdd) {
                        config.capAdd.append(capAdd)
                        capAdd = ""
                    }
                    arrayRows(config.capAdd, icon: "plus.circle") { value in
                        config.capAdd.removeAll { $0 == value }
                    }

                    addArraySectionRow(language.localized("Capability to drop"), text: $capDrop) {
                        config.capDrop.append(capDrop)
                        capDrop = ""
                    }
                    arrayRows(config.capDrop, icon: "minus.circle") { value in
                        config.capDrop.removeAll { $0 == value }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 680)
        .navigationTitle(language.localized("Create Container"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(language.localized("Cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Create")) {
                    Task {
                        await viewModel.createContainer(config: config)
                    }
                }
                .disabled(config.name.isEmpty || config.image.isEmpty)
            }
        }
    }

    private var envVarsList: some View {
        ForEach(Array(config.env.keys.sorted()), id: \.self) { key in
            let value = config.env[key] ?? ""
            HStack {
                Text(key)
                    .font(.system(size: 12, design: .monospaced))
                Text("=")
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button {
                    config.env.removeValue(forKey: key)
                } label: {
                    SwiftUI.Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addEnvVarRow: some View {
        HStack {
            TextField(language.localized("Key"), text: $envKey)
                .textFieldStyle(.roundedBorder)
            TextField(language.localized("Value"), text: $envValue)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !envKey.isEmpty else { return }
                config.env[envKey] = envValue
                envKey = ""
                envValue = ""
            } label: {
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(envKey.isEmpty)
        }
    }

    private var volumesList: some View {
        ForEach(config.volumes, id: \.self) { volume in
            HStack {
                SwiftUI.Image(systemName: "externaldrive")
                    .foregroundStyle(.secondary)
                Text(volume)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button {
                    config.volumes.removeAll { $0 == volume }
                } label: {
                    SwiftUI.Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addVolumeRow: some View {
        HStack {
            TextField(language.localized("Host Path"), text: $volumeSource)
                .textFieldStyle(.roundedBorder)
            Text(":")
                .foregroundStyle(.secondary)
            TextField(language.localized("Container Path"), text: $volumeDest)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !volumeSource.isEmpty, !volumeDest.isEmpty else { return }
                config.volumes.append("\(volumeSource):\(volumeDest)")
                volumeSource = ""
                volumeDest = ""
            } label: {
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(volumeSource.isEmpty || volumeDest.isEmpty)
        }
    }

    private func arrayRows(_ items: [String], icon: String, remove: @escaping (String) -> Void) -> some View {
        ForEach(items, id: \.self) { item in
            HStack {
                SwiftUI.Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(item)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Button {
                    remove(item)
                } label: {
                    SwiftUI.Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addArraySectionRow(_ placeholder: String, text: Binding<String>, add: @escaping () -> Void) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                add()
            } label: {
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview {
    CreateContainerSheet(viewModel: ContainerListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
