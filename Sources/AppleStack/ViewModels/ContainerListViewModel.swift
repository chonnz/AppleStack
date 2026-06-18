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
    var showError = false
    var showAllContainers = true
    var searchText = ""
    var selectedFilter: ContainerFilter = .all
    var showCreateSheet = false
    var inspectOutput = ""
    var showInspectSheet = false
    var showCopySheet = false
    var copySource = ""
    var copyDestination = ""
    
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
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = saved >= 5 ? saved : refreshInterval
    }
    
    func loadContainers() async {
        isLoading = true
        errorMessage = nil
        do {
            containers = try await service.listContainers(all: showAllContainers)
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
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
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }
    
    func stop(_ container: Container) async {
        do {
            try await service.stopContainer(id: container.id)
            await loadContainers()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }
    
    func delete(_ container: Container, force: Bool = false) async {
        do {
            try await service.removeContainer(id: container.id, force: force)
            await loadContainers()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }
    
    func createContainer(config: ContainerConfig) async {
        do {
            try await service.createContainer(config: config)
            await loadContainers()
            showCreateSheet = false
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func inspect(_ container: Container) async {
        do {
            inspectOutput = try await service.inspectContainers(ids: [container.id])
            showInspectSheet = true
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func kill(_ container: Container) async {
        do {
            try await service.killContainers(ids: [container.id], signal: nil, all: false)
            await loadContainers()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func pruneStoppedContainers() async {
        do {
            try await service.pruneContainers()
            await loadContainers()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func export(_ container: Container, to outputPath: String) async {
        do {
            _ = try await service.exportContainer(id: container.id, outputPath: outputPath)
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }

    func copyPath() async {
        do {
            try await service.copyContainerPath(source: copySource, destination: copyDestination)
            showCopySheet = false
            copySource = ""
            copyDestination = ""
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            showError = true
        }
    }
}
