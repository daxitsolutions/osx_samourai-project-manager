import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct DatabaseApplicationTests {
    @Test
    func loadRestoreAndAPIProduceTheSameNormalizedDatabase() async throws {
        let input = fixture()
        try await withStore(input) { loaded, _ in
            let expected = loaded.apiDatabaseSnapshot()
            #expect(expected.activities[0].scenarioID == expected.projects.first(where: { $0.id == input.activities[0].projectID })?.defaultPlanningScenarioID)
            #expect(expected.activities[0].predecessorActivityIDs.isEmpty)
            #expect(expected.events[0].subject == "Événement")
            #expect(expected.resources.allSatisfy { !$0.assignedProjectIDs.contains(orphanID) })
            #expect(expected.actions[0].assignedResourceID == input.actions[0].assignedResourceID)
            #expect(expected.actions[0].expectedDeliverableIDs == input.actions[0].expectedDeliverableIDs)

            try await withStore(.empty) { restored, file in
                let backup = try SamouraiPersistence.makeEncoder().encode(
                    SamouraiBackupEnvelope(appVersion: "test", database: input)
                )
                _ = try restored.restoreBackupData(backup)
                #expect(try encoded(restored.apiDatabaseSnapshot()) == encoded(expected))
                let saved = try SamouraiPersistence.makeDecoder().decode(SamouraiDatabase.self, from: Data(contentsOf: file))
                // Le fichier restauré doit contenir la version normalisée visible dans le store.
                #expect(try encoded(saved) == encoded(expected))
            }
            try await withStore(.empty) { replaced, _ in
                try replaced.apiReplaceDatabase(input)
                #expect(try encoded(replaced.apiDatabaseSnapshot()) == encoded(expected))
            }
        }
    }

    @Test
    func invalidReplacementDoesNotPublishOrOverwriteAnyCollection() async throws {
        var invalid = fixture()
        invalid.activities[0].projectID = UUID()
        try await withStore(fixture()) { store, file in
            let before = try encoded(store.apiDatabaseSnapshot())
            let disk = try Data(contentsOf: file)
            #expect(throws: SamouraiBackupError.self) { try store.apiReplaceDatabase(invalid) }
            let backup = try SamouraiPersistence.makeEncoder().encode(
                SamouraiBackupEnvelope(appVersion: "test", database: invalid)
            )
            #expect(throws: SamouraiBackupError.self) { try store.restoreBackupData(backup) }
            #expect(try encoded(store.apiDatabaseSnapshot()) == before)
            #expect(try Data(contentsOf: file) == disk)
        }
    }

    @Test
    func legacyProjectArrayStillLoadsThroughTheCommonPath() async throws {
        let projects = fixture().projects
        try await withStore(.empty) { _, file in
            try SamouraiPersistence.makeEncoder().encode(projects).write(to: file)
            let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: file, migrationSourceURL: nil))
            await store.loadIfNeeded()
            #expect(store.canEdit)
            #expect(Set(store.projects.map(\.id)) == Set(projects.map(\.id)))
            #expect(store.resources.isEmpty)
        }
    }

    private let orphanID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!

    private func fixture() -> SamouraiDatabase {
        let projects = SamouraiSeedFactory.makeDemoProjects()
        var resources = SamouraiSeedFactory.makeDemoResources(projects: projects)
        resources[0].assignedProjectIDs = [projects[0].id, orphanID]
        let activity = ProjectActivity(projectID: projects[0].id, scenarioID: UUID(),
            title: "Activité", estimatedStartDate: .now, estimatedEndDate: .now)
        var database = SamouraiDatabase(projects: projects, resources: resources, activities: [activity],
            events: [ProjectEvent(subject: "  Événement  ", resourceIDs: [resources[0].id, orphanID])],
            actions: [ProjectAction(title: "Action", details: "", priority: .minor, dueDate: .now,
                flow: .manuel, projectID: projects[0].id, activityID: activity.id,
                assignedResourceID: resources[0].id, expectedDeliverableIDs: [projects[0].deliverables[0].id])])
        database.activities[0].predecessorActivityIDs = [orphanID]
        return database
    }

    private func encoded(_ database: SamouraiDatabase) throws -> Data {
        let encoder = SamouraiPersistence.makeEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(database)
    }

    private func withStore(_ database: SamouraiDatabase, test: (SamouraiStore, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-database-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "projects.json")
        try encoded(database).write(to: file)
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: file, migrationSourceURL: nil))
        await store.loadIfNeeded()
        #expect(store.canEdit)
        try await test(store, file)
    }
}
