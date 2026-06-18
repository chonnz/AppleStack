import SwiftUI

struct ImageListView: View {
    @Bindable var viewModel: ImageListViewModel
    @Binding var selectedImage: Image?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var isSearchExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: "Images",
                subtitle: viewModel.headerSubtitle,
                leadingAccessory: nil,
                leadingInset: 0
            ) {
                headerActions
            }

            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredImages.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "square.3.layers.3d.down.right")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text("No images")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.groupedImages) { group in
                            HStack {
                                Text(group.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.images.count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 14)
                            .padding(.bottom, 6)

                            ForEach(group.images) { image in
                                ImageRowView(
                                    image: image,
                                    isSelected: selectedImage?.id == image.id,
                                    usageSummary: viewModel.usageSummary(for: image),
                                    isDangling: viewModel.isDanglingImage(image),
                                    onDelete: { Task { await viewModel.deleteImage(image) } },
                                    onPull: { Task { await viewModel.pullImage(name: image.reference) } },
                                    onInspect: { Task { await viewModel.inspect(image) } },
                                    onTag: {
                                        viewModel.selectedImageForAction = image
                                        viewModel.tagTarget = image.reference
                                        viewModel.showTagSheet = true
                                    },
                                    onPush: {
                                        viewModel.selectedImageForAction = image
                                        viewModel.showPushSheet = true
                                    },
                                    onSave: { save(image) }
                                )
                                .onTapGesture {
                                    selectedImage = image
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .sheet(isPresented: $viewModel.showPullSheet) {
            PullImageSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showInspectSheet) {
            InspectOutputSheet(title: "Image Inspect", output: viewModel.inspectOutput)
        }
        .sheet(isPresented: $viewModel.showTagSheet) {
            TagImageSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPushSheet) {
            PushImageSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBuildSheet) {
            BuildImageSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button("OK") {
                viewModel.showError = false
            }
            if viewModel.errorMessage != nil {
                Button("Retry") {
                    viewModel.showError = false
                    Task { await viewModel.loadImages() }
                }
                Button("Start System") {
                    viewModel.showError = false
                    Task {
                        try? await CLIBackend().systemStart()
                        await viewModel.loadImages()
                    }
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadImages()
        }
    }

    private func loadImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.loadImage(from: url.path) }
        }
    }

    private func save(_ image: Image) {
        let panel = NSSavePanel()
        let exportTag = image.tag.isEmpty ? "image" : image.tag
        panel.nameFieldStringValue = "\(image.repository.replacingOccurrences(of: "/", with: "_"))-\(exportTag).tar"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.save(image, to: url.path) }
        }
    }

    private func buildImage() {
        viewModel.showBuildSheet = true
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
            buildButton
            loadButton
            searchToggle(width: 110)
            pullButton
        }
    }

    private var compactHeaderActions: some View {
        HStack(spacing: 8) {
            searchToggle(width: 90)
            pullButton
            overflowMenu
        }
    }

    private var minimalHeaderActions: some View {
        HStack(spacing: 8) {
            pullButton
            overflowMenu
        }
    }

    private var buildButton: some View {
        HeaderCircleButton(
            systemName: "hammer",
            action: { buildImage() },
            helpText: "Build image"
        )
    }

    private var loadButton: some View {
        HeaderCircleButton(
            systemName: "tray.and.arrow.down",
            action: { loadImage() },
            helpText: "Load image archive"
        )
    }

    private var pullButton: some View {
        HeaderCircleButton(
            systemName: "plus",
            action: { viewModel.showPullSheet = true },
            helpText: "Pull Image"
        )
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: "More actions") {
            searchMenuActions
            Divider()
            Button("Build Image") {
                buildImage()
            }
            Button("Load Image Archive") {
                loadImage()
            }
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(isSearchExpanded ? "Hide Search" : "Search") {
                isSearchExpanded.toggle()
            }

            if !viewModel.searchText.isEmpty {
                Button("Clear Search") {
                    viewModel.searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $viewModel.searchText,
            isExpanded: $isSearchExpanded,
            placeholder: "Search",
            width: width
        )
    }
}

private struct TagImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Tag Image") {
                TextField("Target reference", text: $viewModel.tagTarget)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Tag") { Task { await viewModel.tagSelectedImage() } }
                    .disabled(viewModel.tagTarget.isEmpty)
            }
        }
    }
}

private struct PushImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Push Image") {
                TextField("Platform (optional, e.g. linux/arm64)", text: $viewModel.pushPlatform)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Push") { Task { await viewModel.pushSelectedImage() } }
            }
        }
    }
}

private struct BuildImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss

    private let machineStarterTemplate = """
    FROM ubuntu:24.04

    ENV container docker

    RUN apt-get update && \
        apt-get install -y systemd systemd-sysv dbus sudo iproute2 iputils-ping curl vim && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        : > /etc/machine-id && \
        : > /var/lib/dbus/machine-id && \
        systemctl mask systemd-firstboot.service systemd-resolved.service && \
        systemctl set-default multi-user.target

    VOLUME ["/sys/fs/cgroup"]

    CMD ["/sbin/init"]
    """

    var body: some View {
        Form {
            Section("Build Image") {
                TextField("Context directory", text: $viewModel.buildContext)
                TextField("Dockerfile/Containerfile path", text: $viewModel.buildFile)
                TextField("Tag", text: $viewModel.buildTag)
                TextField("Platform (optional)", text: $viewModel.buildPlatform)
                TextField("DNS nameserver (optional)", text: $viewModel.buildDNS)
            }

            Section {
                Text("For `container machine`, prefer building a custom image instead of using a generic distro tag directly.")
                    .foregroundStyle(.secondary)
                Text("The image should provide `/sbin/init` at the root. If your build installs packages with `apt` or similar tools, configuring DNS can help avoid network resolution failures during build.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button("Use Machine Build Defaults") {
                    viewModel.applyMachineBuildDefaults()
                }
                .buttonStyle(.bordered)
            } header: {
                Text("Machine-Compatible Images")
            } footer: {
                Text("Recommended workflow from the tutorial: build a machine-oriented image first, then use that resulting image reference in the Machines view.")
            }

            Section {
                Text("Starter Containerfile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(machineStarterTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 180, maxHeight: 220)
            } footer: {
                Text("Starter example based on the tutorial's machine-image requirements: use a base image with `/sbin/init`, reset machine-id files, and boot to a non-GUI target. Save this as `Containerfile`, then build it from the Images view.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Build") { Task { await viewModel.buildImage() } }
                    .disabled(viewModel.buildContext.isEmpty)
            }
        }
    }
}

#Preview {
    ImageListView(
        viewModel: ImageListViewModel(service: ContainerServiceFactory.create()),
        selectedImage: .constant(nil)
    )
}
