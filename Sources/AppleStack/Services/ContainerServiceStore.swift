import SwiftUI

@MainActor
final class ContainerServiceStore: ObservableObject {
    @Published private(set) var service: ContainerServiceProtocol
    @Published private(set) var generation = 0

    init(service: ContainerServiceProtocol = ContainerServiceFactory.create()) {
        self.service = service
    }

    @discardableResult
    func refreshBackend() -> ContainerServiceProtocol {
        service = ContainerServiceFactory.create()
        generation += 1
        return service
    }
}
