import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct BackupRoundTripTests {
    @Test(arguments: ["raw-duplicate", "envelope-duplicate", "unsupported-schema", "invalid-envelope"])
    func rejectedBackupPreservesCurrentState(_ kind: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-backup-rejection-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "projects.json")
        try SamouraiPersistence.saveSynchronously(.empty, to: fileURL)
        let before = try Data(contentsOf: fileURL)
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil))
        await store.loadIfNeeded()
        let project = SamouraiSeedFactory.makeDemoProjects()[0]
        let duplicate = SamouraiDatabase(projects: [project, project], resources: [])
        let encoder = SamouraiPersistence.makeEncoder()
        let payload: Data
        switch kind {
        case "raw-duplicate": payload = try encoder.encode(duplicate)
        case "envelope-duplicate": payload = try encoder.encode(SamouraiBackupEnvelope(appVersion: "test", database: duplicate))
        case "unsupported-schema": payload = try encoder.encode(SamouraiBackupEnvelope(schemaVersion: 999, appVersion: "test", database: .empty))
        default:
            // Les clés d'une base brute ne permettent pas de contourner une enveloppe invalide.
            payload = Data(#"{"format":"wrong","projects":[],"resources":[]}"#.utf8)
        }
        #expect(throws: SamouraiBackupError.self) { try store.restoreBackupData(payload) }
        #expect(store.loadState == .ready)
        #expect(store.projects.isEmpty)
        #expect(try Data(contentsOf: fileURL) == before)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "recovery-backups").path))
    }

    @Test(arguments: ["samourai-backup", "json"], [false, true])
    func exportedBackupRestoresAndReloadsWithoutDataLoss(_ fileExtension: String, _ automatic: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-roundtrip-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appending(path: "source/projects.json")
        let destinationURL = directory.appending(path: "destination/projects.json")
        let projects = SamouraiSeedFactory.makeDemoProjects()
        let activity = ProjectActivity(
            projectID: projects[0].id, scenarioID: projects[0].defaultPlanningScenarioID,
            title: "Activité liée", estimatedStartDate: .now, estimatedEndDate: .now
        )
        let fixture = SamouraiDatabase(
            projects: projects,
            resources: SamouraiSeedFactory.makeDemoResources(projects: projects),
            activities: [activity],
            actions: [ProjectAction(
                title: "Action liée", details: "Texte accentué — 日本語", priority: .minor,
                dueDate: .now, flow: .manuel, projectID: projects[0].id, activityID: activity.id
            )]
        )
        try SamouraiPersistence.saveSynchronously(fixture, to: sourceURL)
        let source = SamouraiStore(persistence: SamouraiPersistence(fileURL: sourceURL, migrationSourceURL: nil))
        await source.loadIfNeeded()
        #expect(source.loadState == .ready)
        let backupData = try source.exportBackupData()
        let expected = try SamouraiPersistence.makeDecoder().decode(SamouraiBackupEnvelope.self, from: backupData)
        let backupURL = directory.appending(path: "export.\(fileExtension)")
        if automatic {
            let persistence = SamouraiPersistence(fileURL: sourceURL, migrationSourceURL: nil)
            try await persistence.save(expected.database)
            let backups = try FileManager.default.contentsOfDirectory(
                at: sourceURL.deletingLastPathComponent().appending(path: "auto-backups"),
                includingPropertiesForKeys: nil
            )
            let autoBackup = try #require(backups.first)
            try Data(contentsOf: autoBackup).write(to: backupURL)
        } else {
            try backupData.write(to: backupURL)
        }

        try SamouraiPersistence.saveSynchronously(.empty, to: destinationURL)
        let destination = SamouraiStore(persistence: SamouraiPersistence(fileURL: destinationURL, migrationSourceURL: nil))
        await destination.loadIfNeeded()
        let priorBytes = try Data(contentsOf: destinationURL)
        let result = try destination.restoreBackupData(Data(contentsOf: backupURL))
        let preservedFiles = try FileManager.default.contentsOfDirectory(
            at: destinationURL.deletingLastPathComponent().appending(path: "recovery-backups"),
            includingPropertiesForKeys: nil
        )
        let preserved = try #require(preservedFiles.first)
        #expect(try Data(contentsOf: preserved) == priorBytes)
        #expect(result.projectCount == fixture.projects.count)
        #expect(result.resourceCount == fixture.resources.count)
        #expect(result.activityCount == 1)
        #expect(result.actionCount == 1)
        #expect(destination.actions.first?.activityID == activity.id)
        #expect(Set(destination.resources.map(\.id)) == Set(fixture.resources.map(\.id)))
        let encoder = SamouraiPersistence.makeEncoder()
        let expectedBytes = try encoder.encode(expected.database)
        let restoredExport = try SamouraiPersistence.makeDecoder().decode(SamouraiBackupEnvelope.self, from: destination.exportBackupData())
        #expect(try encoder.encode(restoredExport.database) == expectedBytes)

        // Le fichier principal JSON et l'enveloppe exportée ont des contrats distincts.
        let stored = try SamouraiPersistence.makeDecoder().decode(SamouraiDatabase.self, from: Data(contentsOf: destinationURL))
        #expect(try encoder.encode(stored) == expectedBytes)
        let reloaded = SamouraiStore(persistence: SamouraiPersistence(fileURL: destinationURL, migrationSourceURL: nil))
        await reloaded.loadIfNeeded()
        #expect(reloaded.loadState == .ready)
        let secondExport = try SamouraiPersistence.makeDecoder().decode(SamouraiBackupEnvelope.self, from: reloaded.exportBackupData())
        #expect(secondExport.format == SamouraiBackupEnvelope.formatIdentifier)
        #expect(secondExport.schemaVersion == SamouraiBackupEnvelope.currentSchemaVersion)
        #expect(try encoder.encode(secondExport.database) == expectedBytes)
    }
}
