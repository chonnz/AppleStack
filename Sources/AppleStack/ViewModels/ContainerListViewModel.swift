import Foundation
import SwiftUI

enum ContainerFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case running = "Running"
    case stopped = "Stopped"
    
    var id: String { rawValue }
}

@MainActor
@Observable
final class ContainerListViewModel {
    var containers: [Container] = []
    var isLoading = false
    var errorMessage: String?
    var showAllContainers = true
    var searchText = ""
    var selectedFilter: ContainerFilter = .all
    var showCreateSheet = false
    
    var filteredContainers: [Container] {
        containers.filter { container in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .running: matchesFilter = container.state == .running
            case .stopped: matchesFilter = container.state == .exited
            }
            let matchesSearch = searchText.isEmpty ||
                container.name.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }
    
    private nonisolated(unsafe) let service: ContainerServiceProtocol
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval
    
    init(service: ContainerServiceProtocol, refreshInterval: TimeInterval = 10) {
        self.service = service
        self.refreshInterval = refreshInterval
    }
    
    func loadContainers() async {
        isLoading = true
        errorMessage = nil
        do {
            containers = try await service.listContainers(all: showAllContainers)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 10))
                guard !Task.isCancelled else { break }
                await self?.loadContainers()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func toggleShowAll() {
        showAllContainers.toggle()
        Task { await loadContainers() }
    }
    
    func start(_ container: Container) async {
        do {
            try await service.startContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stop(_ container: Container) async {
        do {
            try await service.stopContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func delete(_ container: Container, force: Bool = false) async {
        do {
            try await service.removeContainer(id: container.id, force: force)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createContainer(config: ContainerConfig) async {
        do {
            try await service.createContainer(config: config)
            await loadContainers()
            showCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
