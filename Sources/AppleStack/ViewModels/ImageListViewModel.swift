import Foundation
import SwiftUI

@MainActor
@Observable
final class ImageListViewModel {
    var images: [Image] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    
    var filteredImages: [Image] {
        guard !searchText.isEmpty else { return images }
        return images.filter {
            $0.repository.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private nonisolated(unsafe) let service: ContainerServiceProtocol
    
    init(service: ContainerServiceProtocol) {
        self.service = service
    }
    
    func loadImages() async {
        isLoading = true
        errorMessage = nil
        do {
            images = try await service.listImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func pullImage(name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.pullImage(name: name)
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func deleteImage(_ image: Image) async {
        do {
            try await service.removeImage(id: image.id)
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
