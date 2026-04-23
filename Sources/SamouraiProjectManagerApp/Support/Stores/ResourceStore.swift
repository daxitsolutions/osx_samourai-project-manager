import Foundation

@MainActor
@Observable
final class ResourceStore {
    var resources: [Resource] = []

    func replaceResources(_ resources: [Resource]) {
        self.resources = resources
    }

    func reset() {
        resources = []
    }

    func resource(with id: UUID) -> Resource? {
        resources.first { $0.id == id }
    }
}
