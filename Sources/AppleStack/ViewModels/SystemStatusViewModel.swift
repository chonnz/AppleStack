import Foundation
import SwiftUI

@MainActor
@Observable
final class SystemStatusViewModel {
    var systemInfo: SystemInfo?
    var isLoading = false
    var errorMessage: String?
    
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
    
    func loadSystemInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            systemInfo = try await service.getSystemInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
