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
    var isActionRunning = false
    var dnsDomain = ""
    var dnsLocalhost = ""
    var kernelPath = ""
    
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
    
    private let service: ContainerServiceProtocol
    
    init(service: ContainerServiceProtocol) {
        self.service = service
    }
    
    func loadStatus(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            systemInfo = try await service.getSystemInfo()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
        if showLoading {
            isLoading = false
        }
    }

    func startSystem() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await service.systemStart()
            try await waitForSystem { $0.isRunning }
            await loadStatus(showLoading: false)
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            await loadStatus(showLoading: false)
        }
    }

    func stopSystem() async {
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await service.systemStop()
            try await waitForSystem { !$0.isRunning }
            await loadStatus(showLoading: false)
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
            await loadStatus(showLoading: false)
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

    func showDNS() async {
        await runOutput(title: "System DNS") { try await service.systemDNSList() }
    }

    func createDNS() async {
        let domain = dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty else { return }
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await service.systemDNSCreate(
                domain: domain,
                localhost: dnsLocalhost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dnsLocalhost
            )
            dnsDomain = ""
            dnsLocalhost = ""
            await showDNS()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
    }

    func deleteDNS() async {
        let domain = dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty else { return }
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await service.systemDNSDelete(domain: domain)
            dnsDomain = ""
            await showDNS()
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
    }

    func setKernel() async {
        let path = kernelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        guard !isActionRunning else { return }
        isActionRunning = true
        defer { isActionRunning = false }
        do {
            try await service.systemKernelSet(path: path)
            kernelPath = ""
            await runOutput(title: "Kernel", operation: { "Kernel set to \(path)" })
        } catch {
            errorMessage = ContainerServiceErrorPresenter.message(for: error)
        }
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

    private func waitForSystem(
        timeoutSeconds: Double = 45,
        matches: (SystemInfo) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let info = try await service.getSystemInfo()
            systemInfo = info
            if matches(info) {
                return
            }
            try await Task.sleep(for: .milliseconds(700))
        }
    }
}
