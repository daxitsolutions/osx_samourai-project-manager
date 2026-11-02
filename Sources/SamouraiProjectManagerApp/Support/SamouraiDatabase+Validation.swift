import Foundation

extension SamouraiDatabase {
    /// À appeler avant de publier les données ou de construire des dictionnaires à clés uniques.
    /// Les références orphelines restent traitées séparément par les routines de normalisation.
    func validateUniqueIdentifiers() throws {
        try requireUniqueIDs(projects, message: "IDs projets dupliqués.")
        try requireUniqueIDs(resources, message: "IDs ressources dupliqués.")
        try requireUniqueIDs(projects.flatMap(\.risks) + unassignedRisks, message: "IDs risques dupliqués.")
        try requireUniqueIDs(projects.flatMap(\.deliverables), message: "IDs livrables dupliqués.")
        try requireUniqueIDs(activities, message: "IDs activités dupliqués.")
        try requireUniqueIDs(events, message: "IDs événements dupliqués.")
        try requireUniqueIDs(actions, message: "IDs actions dupliqués.")
        try requireUniqueIDs(meetings, message: "IDs réunions dupliqués.")
        try requireUniqueIDs(decisions, message: "IDs décisions dupliqués.")
        try requireUniqueIDs(governanceReports, message: "IDs rapports dupliqués.")
    }

    private func requireUniqueIDs<Entity: Identifiable>(_ entities: [Entity], message: String) throws {
        var seen = Set<Entity.ID>()
        for entity in entities {
            guard seen.insert(entity.id).inserted else {
                throw SamouraiBackupError.invalidPayload(AppLocalizer.localized(message))
            }
        }
    }
}
