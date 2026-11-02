import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct StoreLoadingTests {
    enum DuplicateKind: CaseIterable {
        case activities, projects, resources, deliverables, sharedRisk
    }

    @Test(arguments: DuplicateKind.allCases)
    func rejectsDuplicateIdentifiersBeforePublishing(_ kind: DuplicateKind) async throws {
        var database = makeDatabase()
        switch kind {
        case .activities:
            database.activities.append(database.activities[0])
        case .projects:
            database.projects.append(database.projects[0])
        case .resources:
            database.resources.append(database.resources[0])
        case .deliverables:
            database.projects[0].deliverables.append(database.projects[0].deliverables[0])
        case .sharedRisk:
            database.unassignedRisks.append(database.projects[0].risks[0])
        }

        try await withStoredDatabase(database) { store, fileURL, originalData in
            await store.loadIfNeeded()

            #expect(store.hasLoaded)
            #expect(store.lastErrorMessage != nil)
            #expect(store.projects.isEmpty)
            #expect(store.resources.isEmpty)
            #expect(store.activities.isEmpty)

            // Même après une mutation et la fermeture, le fichier rejeté reste intact.
            _ = store.addProject(
                name: "Projet temporaire", summary: "", sponsor: "", manager: "",
                phase: .cadrage, health: .green, deliveryMode: .waterfall,
                startDate: .now, targetDate: .now
            )
            store.flushSynchronously()
            let savedData = try Data(contentsOf: fileURL)
            #expect(savedData == originalData)
            #expect(!FileManager.default.fileExists(
                atPath: fileURL.deletingLastPathComponent().appending(path: "auto-backups").path
            ))
        }
    }

    @Test
    func validDatabaseStillLoadsAndNormalizesOrphanReferences() async throws {
        var database = makeDatabase()
        var orphan = database.activities[0]
        orphan.id = UUID()
        orphan.projectID = UUID()
        database.activities.append(orphan)
        database.activities[0].predecessorActivityIDs = [UUID()]
        database.actions = [ProjectAction(
            title: "Action", details: "", priority: .minor, dueDate: .now,
            flow: .manuel, projectID: database.projects[0].id, activityID: UUID()
        )]

        try await withStoredDatabase(database) { store, _, _ in
            await store.loadIfNeeded()

            #expect(store.lastErrorMessage == nil)
            #expect(store.projects.count == database.projects.count)
            #expect(store.activities.count == 1)
            #expect(store.activities[0].predecessorActivityIDs.isEmpty)
            #expect(store.actions[0].activityID == nil)
        }
    }

    @Test
    func distinctDeliverablesMayHaveTheSameTitle() async throws {
        var database = makeDatabase()
        var homonym = database.projects[0].deliverables[0]
        homonym.id = UUID()
        database.projects[0].deliverables.append(homonym)

        try await withStoredDatabase(database) { store, _, _ in
            await store.loadIfNeeded()
            #expect(store.lastErrorMessage == nil)
            #expect(store.projects.count == database.projects.count)
        }
    }

    @Test
    func validDatabaseCanBeSavedToItsInjectedLocation() async throws {
        try await withStoredDatabase(makeDatabase()) { store, fileURL, _ in
            await store.loadIfNeeded()
            let project = try #require(store.projects.first)
            try FileManager.default.removeItem(at: fileURL)
            store.flushSynchronously()

            let saved = try SamouraiPersistence.makeDecoder().decode(
                SamouraiDatabase.self, from: Data(contentsOf: fileURL)
            )
            #expect(saved.projects.first(where: { $0.id == project.id })?.name == project.name)
        }
    }

    @Test
    func restorationAndAPIAlsoRejectDuplicateNestedIdentifiers() throws {
        var database = makeDatabase()
        database.projects[0].deliverables.append(database.projects[0].deliverables[0])
        let store = SamouraiStore()
        let backup = try SamouraiPersistence.makeEncoder().encode(
            SamouraiBackupEnvelope(appVersion: "test", database: database)
        )

        #expect(throws: SamouraiBackupError.self) { try store.restoreBackupData(backup) }
        #expect(throws: SamouraiBackupError.self) { try store.apiReplaceDatabase(database) }
        #expect(store.projects.isEmpty)
    }

    private func makeDatabase() -> SamouraiDatabase {
        let projects = SamouraiSeedFactory.makeDemoProjects()
        let activity = ProjectActivity(
            projectID: projects[0].id, scenarioID: projects[0].defaultPlanningScenarioID,
            title: "Activité", estimatedStartDate: .now, estimatedEndDate: .now
        )
        return SamouraiDatabase(
            projects: projects,
            resources: SamouraiSeedFactory.makeDemoResources(projects: projects),
            activities: [activity]
        )
    }

    private func withStoredDatabase(
        _ database: SamouraiDatabase,
        test: @MainActor (SamouraiStore, URL, Data) async throws -> Void
    ) async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: "samourai-loading-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appending(path: "projects.json")
        var originalData = try SamouraiPersistence.makeEncoder().encode(database)
        originalData.append(Data("\n".utf8))
        try originalData.write(to: fileURL)
        let persistence = SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil)
        let store = SamouraiStore(persistence: persistence)
        try await test(store, fileURL, originalData)
    }
}
