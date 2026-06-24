import Foundation
import SwiftUI

@MainActor
@Observable
final class ImageListViewModel {
    private static let lastBuiltMachineImageReferenceKey = "appleStack.lastBuiltMachineImageReference"

    struct ImageGroup: Identifiable {
        let title: String
        let images: [Image]

        var id: String { title }
    }

    var images: [Image] = []
    var containers: [Container] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false
    var searchText = ""
    var showPullSheet = false
    var showInspectSheet = false
    var showTagSheet = false
    var showPushSheet = false
    var showBuildSheet = false
    var inspectOutput = ""
    var selectedImageForAction: Image?
    var tagTarget = ""
    var pushPlatform = ""
    var buildContext = "."
    var buildFile = ""
    var buildTag = ""
    var buildPlatform = ""
    var buildDNS = ""
    var pendingImageIDs: Set<String> = []
    var activeGlobalOperations = 0
    
    var filteredImages: [Image] {
        guard !searchText.isEmpty else { return images }
        return images.filter {
            $0.repository.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedImages: [ImageGroup] {
        let filtered = filteredImages
        let inUse = filtered.filter(isImageInUse)
        let dangling = filtered.filter(isDanglingImage)
        let unused = filtered.filter { !isImageInUse($0) && !isDanglingImage($0) }

        return [
            ImageGroup(title: "In Use", images: inUse),
            ImageGroup(title: "Unused", images: unused),
            ImageGroup(title: "Dangling", images: dangling),
        ]
        .filter { !$0.images.isEmpty }
    }

    var totalSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: images.reduce(0) { $0 + $1.size })
    }

    var headerSubtitle: String {
        images.isEmpty ? "0 items" : "\(totalSizeFormatted) total"
    }

    var isOperationRunning: Bool {
        activeGlobalOperations > 0 || !pendingImageIDs.isEmpty
    }
    
    var autoRefresh = false
    private var refreshTask: Task<Void, Never>?
    private nonisolated(unsafe) let service: ContainerServiceProtocol

    init(service: ContainerServiceProtocol) {
        self.service = service
    }

    func startAutoRefresh() {
        guard autoRefresh else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await self?.loadImages()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func loadImages() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedImages = try await service.listImages()
            containers = (try? await service.listContainers(all: true)) ?? []
            images = loadedImages.sorted(by: imageSort)
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
        isLoading = false
    }
    
    func pullImage(name: String) async {
        await runGlobalOperation {
            try await service.pullImage(name: name)
            await loadImages()
        }
    }
    
    func deleteImage(_ image: Image) async {
        if let usageSummary = usageSummary(for: image) {
            errorMessage = "无法删除镜像：\(usageSummary)。请先删除或停止相关容器后再试。"
            showError = true
            return
        }

        await runImageOperation(image) {
            try await service.removeImage(id: image.deleteTarget)
            try await waitForImage(id: image.id, reference: image.reference) { $0 == nil }
            await loadImages()
        }
    }

    func inspect(_ image: Image) async {
        do {
            inspectOutput = try await service.inspectImages(references: [image.reference])
            showInspectSheet = true
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func loadImage(from inputPath: String) async {
        await runGlobalOperation {
            try await service.loadImage(inputPath: inputPath, force: false)
            await loadImages()
        }
    }

    func save(_ image: Image, to outputPath: String) async {
        await runImageOperation(image) {
            _ = try await service.saveImages(references: [image.reference], outputPath: outputPath, platform: nil)
        }
    }

    func tagSelectedImage() async {
        guard let image = selectedImageForAction else { return }
        await runImageOperation(image) {
            try await service.tagImage(source: image.reference, target: tagTarget)
            showTagSheet = false
            tagTarget = ""
            await loadImages()
        }
    }

    func pushSelectedImage() async {
        guard let image = selectedImageForAction else { return }
        await runImageOperation(image) {
            try await service.pushImage(reference: image.reference, platform: pushPlatform.isEmpty ? nil : pushPlatform)
            showPushSheet = false
            pushPlatform = ""
        }
    }

    func pruneImages() async {
        await runGlobalOperation {
            try await service.pruneImages(all: false)
            await loadImages()
        }
    }

    func buildImage() async {
        await runGlobalOperation {
            let options = ImageBuildOptions(
                contextDirectory: buildContext,
                dockerfilePath: buildFile.isEmpty ? nil : buildFile,
                tags: buildTag.isEmpty ? [] : [buildTag],
                platform: buildPlatform.isEmpty ? nil : buildPlatform,
                dns: buildDNS.isEmpty ? nil : buildDNS,
                buildArgs: [:],
                noCache: false,
                pull: false
            )
            _ = try await service.buildImage(options: options)
            if let firstTag = options.tags.first, !firstTag.isEmpty {
                UserDefaults.standard.set(firstTag, forKey: Self.lastBuiltMachineImageReferenceKey)
            }
            showBuildSheet = false
            buildContext = "."
            buildFile = ""
            buildTag = ""
            buildPlatform = ""
            buildDNS = ""
            await loadImages()
        }
    }

    func applyMachineBuildDefaults() {
        if buildFile.isEmpty {
            buildFile = "Containerfile"
        }
        if buildTag.isEmpty {
            buildTag = "machine-ubuntu:24.04"
        }
        if buildPlatform.isEmpty {
            buildPlatform = "linux/arm64"
        }
        if buildDNS.isEmpty {
            buildDNS = "8.8.8.8"
        }
    }

    func usageSummary(for image: Image) -> String? {
        let matchingContainers = containersUsing(image)
        guard !matchingContainers.isEmpty else { return nil }

        if matchingContainers.count == 1, let container = matchingContainers.first {
            return "Used by \(container.name)"
        }

        return "Used by \(matchingContainers.count) containers"
    }

    func isImageInUse(_ image: Image) -> Bool {
        !containersUsing(image).isEmpty
    }

    func isDanglingImage(_ image: Image) -> Bool {
        let repository = image.repository.trimmingCharacters(in: .whitespacesAndNewlines)
        return repository.isEmpty || repository == "<none>"
    }

    private func containersUsing(_ image: Image) -> [Container] {
        let imageCandidates = Set([
            normalizedReference(image.reference),
            normalizedReference(image.repository),
            normalizedReference(image.id),
            normalizedReference(String(image.id.prefix(12))),
        ])

        return containers.filter { container in
            let containerCandidates = Set([
                normalizedReference(container.image),
                normalizedReference(container.id),
                normalizedReference(String(container.image.split(separator: "@").first.map(String.init) ?? container.image)),
            ])

            return !imageCandidates.isDisjoint(with: containerCandidates)
        }
    }

    private func normalizedReference(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("docker.io/library/") {
            value.removeFirst("docker.io/library/".count)
        } else if value.hasPrefix("docker.io/") {
            value.removeFirst("docker.io/".count)
        }
        if value.hasPrefix("sha256:") {
            value.removeFirst("sha256:".count)
        }
        return value
    }

    private func imageSort(lhs: Image, rhs: Image) -> Bool {
        if isImageInUse(lhs) != isImageInUse(rhs) {
            return isImageInUse(lhs)
        }
        if isDanglingImage(lhs) != isDanglingImage(rhs) {
            return !isDanglingImage(lhs)
        }
        if lhs.size != rhs.size {
            return lhs.size > rhs.size
        }
        return lhs.reference.localizedCaseInsensitiveCompare(rhs.reference) == .orderedAscending
    }

    func isPending(_ image: Image) -> Bool {
        pendingImageIDs.contains(image.id)
    }

    private func runGlobalOperation(_ operation: () async throws -> Void) async {
        activeGlobalOperations += 1
        errorMessage = nil
        defer { activeGlobalOperations -= 1 }
        do {
            try await operation()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
            await loadImages()
        }
    }

    private func runImageOperation(_ image: Image, operation: () async throws -> Void) async {
        guard !pendingImageIDs.contains(image.id) else { return }
        pendingImageIDs.insert(image.id)
        errorMessage = nil
        defer { pendingImageIDs.remove(image.id) }
        do {
            try await operation()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
            await loadImages()
        }
    }

    private func waitForImage(
        id: String,
        reference: String,
        timeoutSeconds: Double = 30,
        matches: (Image?) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let latest = try await service.listImages()
            images = latest.sorted(by: imageSort)
            let found = latest.first { image in
                image.id == id || image.reference == reference || image.deleteTarget == reference
            }
            if matches(found) {
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }
    }
}
