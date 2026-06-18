import SwiftUI

private struct CLIBackendKey: EnvironmentKey {
    static let defaultValue: ContainerServiceProtocol = CLIBackend()
}

extension EnvironmentValues {
    var cliBackend: ContainerServiceProtocol {
        get { self[CLIBackendKey.self] }
        set { self[CLIBackendKey.self] = newValue }
    }
}
