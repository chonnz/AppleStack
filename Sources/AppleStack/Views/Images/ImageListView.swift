import SwiftUI

struct ImageListView: View {
    @Bindable var viewModel: ImageListViewModel
    @Binding var selectedImage: Image?
    var showsSidebarToggle: Bool = false
    var onToggleSidebar: () -> Void = {}
    @State private var isSearchExpanded = false
    @State private var imageToDelete: Image?
    @Environment(\.cliBackend) private var cliBackend
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(
                title: language.localized("Images"),
                subtitle: imageHeaderSubtitle,
                leadingAccessory: nil,
                leadingInset: showsSidebarToggle ? AppTheme.windowControlsClearance : 0
            ) {
                headerActions
            }

            if let progress = viewModel.activeOperation {
                OperationProgressView(progress: progress) {
                    viewModel.clearCompletedOperation()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredImages.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "square.3.layers.3d.down.right")
                        .font(.system(size: 52))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("No images"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.showPullSheet = true
                    } label: {
                        Label(language.localized("Pull an image"), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.groupedImages) { group in
                            HStack {
                                Text(language.localized(group.title))
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
                                    isPending: viewModel.isPending(image),
                                    usageSummary: viewModel.usageSummary(for: image),
                                    isDangling: viewModel.isDanglingImage(image),
                                    onDelete: { imageToDelete = image },
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
            InspectOutputSheet(title: language.localized("Image Inspect"), output: viewModel.inspectOutput)
        }
        .sheet(isPresented: $viewModel.showTagSheet) {
            TagImageSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPushSheet) {
            PushImageSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete image \"\(imageToDelete?.displayTitle ?? "")\"?",
            isPresented: .init(
                get: { imageToDelete != nil },
                set: { if !$0 { imageToDelete = nil } }
            )
        ) {
            Button(language.localized("Delete"), role: .destructive) {
                if let img = imageToDelete {
                    Task { await viewModel.deleteImage(img) }
                }
                imageToDelete = nil
            }
            Button(language.localized("Cancel"), role: .cancel) {
                imageToDelete = nil
            }
        } message: {
            Text(language.localized("This action cannot be undone."))
        }
        .sheet(isPresented: $viewModel.showBuildSheet) {
            BuildImageSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button(language.localized("OK")) {
                viewModel.showError = false
            }
            if viewModel.errorMessage != nil {
                Button(language.localized("Retry")) {
                    viewModel.showError = false
                    Task { await viewModel.loadImages() }
                }
                Button(language.localized("Start System")) {
                    viewModel.showError = false
                    Task {
                        try? await cliBackend.systemStart()
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

    private var imageHeaderSubtitle: String {
        viewModel.images.isEmpty
            ? "0 \(language.localized("items"))"
            : "\(viewModel.totalSizeFormatted) \(language.localized("total"))"
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
        HeaderCircleButton(systemName: viewModel.isOperationRunning ? "hourglass" : "hammer", action: { buildImage() }, helpText: language.localized("Build image"))
            .disabled(viewModel.isOperationRunning)
    }

    private var loadButton: some View {
        HeaderCircleButton(systemName: viewModel.isOperationRunning ? "hourglass" : "tray.and.arrow.down", action: { loadImage() }, helpText: language.localized("Load image archive"))
            .disabled(viewModel.isOperationRunning)
    }

    private var pullButton: some View {
        HeaderCircleButton(systemName: viewModel.isOperationRunning ? "hourglass" : "plus", action: { viewModel.showPullSheet = true }, helpText: language.localized("Pull Image"))
            .disabled(viewModel.isOperationRunning)
    }

    private var overflowMenu: some View {
        HeaderMenuButton(helpText: language.localized("More actions")) {
            searchMenuActions
            Divider()
            Button(language.localized("Build Image")) {
                buildImage()
            }
            .disabled(viewModel.isOperationRunning)
            Button(language.localized("Load Image Archive")) {
                loadImage()
            }
            .disabled(viewModel.isOperationRunning)
        }
    }

    private var searchMenuActions: some View {
        Group {
            Button(isSearchExpanded ? language.localized("Hide Search") : language.localized("Search")) {
                isSearchExpanded.toggle()
            }

            if !viewModel.searchText.isEmpty {
                Button(language.localized("Clear Search")) {
                    viewModel.searchText = ""
                }
            }
        }
    }

    private func searchToggle(width: CGFloat) -> some View {
        HeaderSearchToggle(
            text: $viewModel.searchText,
            isExpanded: $isSearchExpanded,
            placeholder: language.localized("Search"),
            width: width
        )
    }
}

private struct TagImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Tag Image")) {
                TextField(language.localized("Target reference"), text: $viewModel.tagTarget)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(language.localized("Cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Tag")) { Task { await viewModel.tagSelectedImage() } }
                    .disabled(viewModel.tagTarget.isEmpty)
            }
        }
    }
}

private struct PushImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Push Image")) {
                TextField(language.localized("Platform (optional, e.g. linux/arm64)"), text: $viewModel.pushPlatform)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 140)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(language.localized("Cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Push")) { Task { await viewModel.pushSelectedImage() } }
            }
        }
    }
}

private struct BuildImageSheet: View {
    @Bindable var viewModel: ImageListViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Form {
            Section(language.localized("Build Image")) {
                TextField(language.localized("Context directory"), text: $viewModel.buildContext)
                TextField(language.localized("Dockerfile/Containerfile path"), text: $viewModel.buildFile)
                TextField(language.localized("Tag"), text: $viewModel.buildTag)
                TextField(language.localized("Platform (optional)"), text: $viewModel.buildPlatform)
                TextField(language.localized("DNS nameserver (optional)"), text: $viewModel.buildDNS)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(language.localized("Cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(language.localized("Build")) {
                    dismiss()
                    Task { await viewModel.buildImage() }
                }
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
