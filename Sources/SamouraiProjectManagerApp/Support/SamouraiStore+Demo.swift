import Foundation

extension SamouraiStore {
    /// Les exemples ne doivent remplacer aucune donnée existante, même sans projet.
    var canLoadDemoData: Bool {
        canEdit && projects.isEmpty && resources.isEmpty && unassignedRisks.isEmpty
            && activities.isEmpty && events.isEmpty && actions.isEmpty
            && meetings.isEmpty && decisions.isEmpty && governanceReports.isEmpty
    }

    func loadDemoData() throws {
        try requireEditableState()
        guard canLoadDemoData else {
            throw RESTAPIError.conflict(AppLocalizer.localized("Les données de démonstration nécessitent une base vide."))
        }
        let projects = SamouraiSeedFactory.makeDemoProjects()
        let resources = SamouraiSeedFactory.makeDemoResources(projects: projects)
        try apiReplaceDatabase(SamouraiDatabase(projects: projects, resources: resources))
    }
}
