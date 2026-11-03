import Foundation

/// One destination, including its captured action data, for every resource presentation.
struct ResourceWorkspacePresentation: Identifiable {
    enum Destination {
        case create
        case edit(UUID)
        case evaluation(UUID)
        case directory
        case memo(UUID)
        case templates(UUID)
        case review
        case importFile
        case exportFile
        case delete([Resource])
        case removeFromProject(Resource)
        case confirmImport([ResourceImportDraft])
        case feedback(title: String, message: String)
    }

    enum Kind { case sheet, alert, importFile, exportFile }

    let id = UUID()
    let destination: Destination

    var kind: Kind {
        switch destination {
        case .create, .edit, .evaluation, .directory, .memo, .templates, .review: .sheet
        case .delete, .removeFromProject, .confirmImport, .feedback: .alert
        case .importFile: .importFile
        case .exportFile: .exportFile
        }
    }
}

struct ResourceWorkspacePresentationState {
    private(set) var current: ResourceWorkspacePresentation?
    private var isActive = true

    func presented(for kind: ResourceWorkspacePresentation.Kind) -> ResourceWorkspacePresentation? {
        current?.kind == kind ? current : nil
    }

    mutating func activate() { isActive = true }

    mutating func deactivate() {
        isActive = false
        current = nil
    }

    mutating func show(_ destination: ResourceWorkspacePresentation.Destination) {
        guard isActive else { return }
        current = ResourceWorkspacePresentation(destination: destination)
    }

    /// A delayed dismissal of an old sheet must not erase its replacement or feedback.
    mutating func dismiss(id: UUID) {
        if current?.id == id { current = nil }
    }

    mutating func dismissAll() {
        current = nil
    }
}
