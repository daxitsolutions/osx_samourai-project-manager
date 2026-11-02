import Foundation

/// Périmètre réellement affiché par le dashboard (#49) : le projet actif ou tout le portefeuille.
/// Titres et indicateurs en dérivent pour rester alignés sur les données montrées.
@MainActor
struct DashboardScope {
    let focusedProject: Project?
    let projects: [Project]
    let risks: [RiskEntry]

    init(store: SamouraiStore, projectID: UUID?) {
        if let projectID, let project = store.project(with: projectID) {
            focusedProject = project
            projects = [project]
            risks = store.risks.filter { $0.projectID == projectID }
        } else {
            focusedProject = nil
            projects = store.projects
            risks = store.risks
        }
    }

    var isProjectScope: Bool { focusedProject != nil }

    var eyebrow: String { focusedProject?.name ?? "Portefeuille" }

    var title: String { isProjectScope ? "Pilotage du projet" : "Pilotage du portefeuille" }

    var subtitle: String {
        isProjectScope
            ? "Signaux, tensions et échéances du projet actif."
            : "Signaux, tensions et échéances de tous les projets."
    }

    var projectsSectionTitle: String { isProjectScope ? "Projet suivi" : "Projets sous contrôle" }

    /// Compté sur les mêmes risques que la liste « Tensions à arbitrer », y compris les risques
    /// sans projet en vue portefeuille.
    var criticalRiskCount: Int {
        risks.filter { $0.risk.severity == .critical }.count
    }
}
