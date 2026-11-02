import Foundation
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #49 : le titre et les indicateurs du dashboard suivent le périmètre réellement affiché.
@MainActor
struct DashboardScopeTests {
    @Test func portfolioScopeCoversAllProjectsAndUnassignedRisks() async throws {
        try await withStore { store, projects in
            let scope = DashboardScope(store: store, projectID: nil)

            #expect(scope.isProjectScope == false)
            #expect(scope.title == "Pilotage du portefeuille")
            #expect(scope.eyebrow == "Portefeuille")
            #expect(scope.projectsSectionTitle == "Projets sous contrôle")
            #expect(scope.projects.map(\.id) == projects.map(\.id))
            // 1 critique dans chaque projet + 1 critique sans projet.
            #expect(scope.criticalRiskCount == 3)
            #expect(scope.criticalRiskCount == scope.risks.filter { $0.risk.severity == .critical }.count)
        }
    }

    @Test func projectScopeShowsOnlyTheActiveProject() async throws {
        try await withStore { store, projects in
            let project = projects[1]
            let scope = DashboardScope(store: store, projectID: project.id)

            #expect(scope.isProjectScope)
            #expect(scope.title == "Pilotage du projet")
            #expect(scope.eyebrow == project.name)
            #expect(scope.projectsSectionTitle == "Projet suivi")
            #expect(scope.projects.map(\.id) == [project.id])
            #expect(scope.risks.allSatisfy { $0.projectID == project.id })
            #expect(scope.criticalRiskCount == 1)
        }
    }

    @Test func unknownProjectFallsBackToPortfolio() async throws {
        try await withStore { store, projects in
            let scope = DashboardScope(store: store, projectID: UUID())
            #expect(scope.isProjectScope == false)
            #expect(scope.projects.count == projects.count)
        }
    }

    @Test func emptyStoreKeepsPortfolioWording() async throws {
        try await withStore(projects: []) { store, _ in
            let scope = DashboardScope(store: store, projectID: nil)
            #expect(scope.title == "Pilotage du portefeuille")
            #expect(scope.projects.isEmpty)
            #expect(scope.criticalRiskCount == 0)
        }
    }

    @Test func newWordingIsLocalized() {
        let keys = ["Portefeuille", "Pilotage du portefeuille", "Pilotage du projet", "Projet suivi", "Santé du projet",
                    "Signaux, tensions et échéances du projet actif.", "Signaux, tensions et échéances de tous les projets."]
        for key in keys {
            #expect(AppLocalizer.localized(key, language: .en) != key, "Clé non traduite : \(key)")
        }
        #expect(AppLocalizer.localized("Pilotage du projet", language: .fr) == "Pilotage du projet")
    }

    // MARK: - Fixtures

    /// Deux projets avec chacun un risque critique, plus un risque critique sans projet.
    private func withStore(
        projects: [Project]? = nil,
        test: (SamouraiStore, [Project]) async throws -> Void
    ) async throws {
        var projects = projects ?? Array(SamouraiSeedFactory.makeDemoProjects().prefix(2))
        for index in projects.indices {
            for riskIndex in projects[index].risks.indices {
                projects[index].risks[riskIndex].severity = riskIndex == 0 ? .critical : .low
            }
            if projects[index].risks.isEmpty, let template = SamouraiSeedFactory.makeDemoProjects().first?.risks.first {
                var risk = template
                risk.id = UUID()
                risk.severity = .critical
                projects[index].risks = [risk]
            }
        }
        var unassigned: [Risk] = []
        if var orphan = projects.first?.risks.first {
            orphan.id = UUID()
            orphan.severity = .critical
            unassigned.append(orphan)
        }

        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-dashboard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "projects.json")
        let database = SamouraiDatabase(projects: projects, resources: [], unassignedRisks: unassigned)
        try SamouraiPersistence.makeEncoder().encode(database).write(to: fileURL)

        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil))
        await store.loadIfNeeded()
        #expect(store.hasLoaded)
        try await test(store, projects)
    }
}
