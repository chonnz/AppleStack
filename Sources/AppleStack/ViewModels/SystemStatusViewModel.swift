import Foundation
import SwiftUI

@MainActor
@Observable
final class SystemStatusViewModel {
    var systemInfo: SystemInfo?
    var isLoading = false
    var errorMessage: String?
    var outputTitle = ""
    var outputText = ""
    var showOutputSheet = false
    
    var isRunning: Bool {
        systemInfo?.isRunning ?? false
    }
    
    var version: String {
        systemInfo?.version ?? "Unknown"
    }
    
    var osInfo: String {
        guard let info = systemInfo else { return "Unknown" }
        return "\(info.os) \(info.arch)"
    }
    
    private nonisolated(unsafe) let service: ContainerServiceProtocol
    
    init(service: ContainerServiceProtocol) {
        self.service = service
    }
    
    func loadStatus() async {
        isLoading = true
        errorMessage = nil
        do {
            systemInfo = try await service.getSystemInfo()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
        isLoading = false
    }

    func startSystem() async {
        do {
            try await service.systemStart()
            await loadStatus()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
    }

    func stopSystem() async {
        do {
            try await service.systemStop()
            await loadStatus()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
    }

    func showVersion() async {
        await runOutput(title: "System Version") { try await service.systemVersion() }
    }

    func showDiskUsage() async {
        await runOutput(title: "Disk Usage") { try await service.systemDiskUsage() }
    }

    func showLogs() async {
        await runOutput(title: "System Logs") { try await service.systemLogs(follow: false, last: "5m") }
    }

    func showProperties() async {
        await runOutput(title: "System Properties") { try await service.systemPropertyList() }
    }

    private func runOutput(title: String, operation: () async throws -> String) async {
        do {
            outputTitle = title
            outputText = try await operation()
            showOutputSheet = true
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
    }
}
