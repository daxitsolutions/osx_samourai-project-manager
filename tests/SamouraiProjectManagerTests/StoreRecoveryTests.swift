import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct StoreRecoveryTests {
    private let corruptData = Data("{invalid-json".utf8)

    @Test
    func failedLoadBlocksMutationsEvenAfterDismissingTheAlert() async throws {
        try await withCorruptFile { store, fileURL in
            #expect(store.loadState == .notLoaded)
            #expect(!store.canEdit)
            await store.loadIfNeeded()
            #expect(store.loadState == .failed)
            let failure = try #require(store.loadFailureMessage)

            store.lastErrorMessage = nil
            #expect(store.loadFailureMessage == failure)
            #expect(!store.hasLoaded)
            let created = store.addProject(
                name: "Ne pas perdre cette saisie", summary: "", sponsor: "", manager: "",
                phase: .cadrage, health: .green, deliveryMode: .waterfall,
                startDate: .now, targetDate: .now
            )
            #expect(created == nil)
            store.deleteAllData()
            #expect(store.projects.isEmpty)
            #expect(!store.canEdit)
            store.flushSynchronously()
            let actual = try Data(contentsOf: fileURL)
            #expect(actual == corruptData)
        }
    }

    @Test
    func APIAndImportsCannotBypassRecovery() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            let project = SamouraiSeedFactory.makeDemoProjects()[0]
            do {
                _ = try store.apiUpsertProject(project)
                Issue.record("L'API devait refuser l'écriture")
            } catch let error as RESTAPIError {
                #expect(error.statusCode == 503)
            }
            #expect(throws: RESTAPIError.self) {
                try store.apiReplaceDatabase(SamouraiDatabase(projects: [project], resources: []))
            }
            #expect(throws: RESTAPIError.self) { try store.exportBackupData() }
            await #expect(throws: RESTAPIError.self) {
                try await store.importRisksAsync([], reporter: .noop)
            }
            await #expect(throws: RESTAPIError.self) {
                try await store.applyResourceImportReviewAsync([], decisions: [], reporter: .noop)
            }
            #expect(store.importResources([]).importedCount == 0)
            #expect(store.importRisks([]).importedCount == 0)
            #expect(store.projects.isEmpty)
            #expect(store.loadState == .failed)
            let actual = try Data(contentsOf: fileURL)
            #expect(actual == corruptData)
        }
    }

    @Test
    func retryOnTheSameStoreLoadsTheRepairedFile() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            #expect(store.loadState == .failed)
            let database = SamouraiDatabase(projects: SamouraiSeedFactory.makeDemoProjects(), resources: [])
            try SamouraiPersistence.makeEncoder().encode(database).write(to: fileURL)

            await store.loadIfNeeded()
            #expect(store.loadState == .ready)
            #expect(store.canEdit)
            #expect(store.hasLoaded)
            #expect(store.projects.count == database.projects.count)
            #expect(store.loadFailureMessage == nil)
            #expect(store.lastErrorMessage == nil)
            try store.requireEditableState()
            store.flushSynchronously()
            let saved = try SamouraiPersistence.makeDecoder().decode(
                SamouraiDatabase.self, from: Data(contentsOf: fileURL)
            )
            #expect(saved.projects.map(\.id) == store.projects.map(\.id))
        }
    }

    @Test
    func unsuccessfulRetryKeepsRecoveryActive() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            store.lastErrorMessage = nil
            await store.loadIfNeeded()
            #expect(store.loadState == .failed)
            #expect(store.loadFailureMessage != nil)
            #expect(!store.canEdit)
            let actual = try Data(contentsOf: fileURL)
            #expect(actual == corruptData)
        }
    }

    @Test
    func restorePreservesRejectedBytesAndWritesBeforeUnlocking() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            let database = SamouraiDatabase(projects: SamouraiSeedFactory.makeDemoProjects(), resources: [])
            let backup = try makeBackup(database)
            _ = try store.restoreBackupData(backup)

            #expect(store.loadState == .ready)
            #expect(store.loadFailureMessage == nil)
            let saved = try SamouraiPersistence.makeDecoder().decode(
                SamouraiDatabase.self, from: Data(contentsOf: fileURL)
            )
            #expect(Set(saved.projects.map(\.id)) == Set(database.projects.map(\.id)))
            let copies = try FileManager.default.contentsOfDirectory(
                at: fileURL.deletingLastPathComponent().appending(path: "recovery-backups"),
                includingPropertiesForKeys: nil
            )
            let copy = try #require(copies.first)
            #expect(copies.count == 1)
            let rejectedBytes = try Data(contentsOf: copy)
            #expect(rejectedBytes == corruptData)
        }
    }

    @Test
    func invalidRestoreDoesNotUnlockOrReplaceTheFile() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            #expect(throws: SamouraiBackupError.self) { try store.restoreBackupData(Data("invalid".utf8)) }
            #expect(store.loadState == .failed)
            #expect(store.projects.isEmpty)
            let actual = try Data(contentsOf: fileURL)
            #expect(actual == corruptData)
        }
    }

    @Test
    func failedPreservationDoesNotUnlockOrOverwriteTheFile() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            let directory = fileURL.deletingLastPathComponent().appending(path: "recovery-backups")
            // Un fichier à cet emplacement empêche la création du dossier de sécurité.
            try Data("obstacle".utf8).write(to: directory)
            let backup = try makeBackup(.empty)
            #expect(throws: (any Error).self) { try store.restoreBackupData(backup) }
            #expect(store.loadState == .failed)
            #expect(!store.canEdit)
            let actual = try Data(contentsOf: fileURL)
            #expect(actual == corruptData)
        }
    }

    private func makeBackup(_ database: SamouraiDatabase) throws -> Data {
        try SamouraiPersistence.makeEncoder().encode(
            SamouraiBackupEnvelope(appVersion: "test", database: database)
        )
    }

    @Test
    func failedRestoreWriteDoesNotUnlockEditing() async throws {
        try await withCorruptFile { store, fileURL in
            await store.loadIfNeeded()
            try FileManager.default.removeItem(at: fileURL)
            try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false)
            let backup = try makeBackup(.empty)
            #expect(throws: (any Error).self) { try store.restoreBackupData(backup) }
            #expect(store.loadState == .failed)
            #expect(!store.canEdit)
            #expect(store.projects.isEmpty)
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            #expect(values.isDirectory == true)
        }
    }

    @Test
    func failedLegacyMigrationCannotStartAnEmptyEditableDatabase() async throws {
        try await withCorruptFile { _, fileURL in
            let root = fileURL.deletingLastPathComponent()
            let legacyURL = root.appending(path: "legacy.json")
            let legacyData = try SamouraiPersistence.makeEncoder().encode(SamouraiDatabase.empty)
            try legacyData.write(to: legacyURL)
            let obstacle = root.appending(path: "obstacle")
            try Data("not-a-directory".utf8).write(to: obstacle)
            let persistence = SamouraiPersistence(
                fileURL: obstacle.appending(path: "projects.json"), migrationSourceURL: legacyURL
            )
            let store = SamouraiStore(persistence: persistence)
            await store.loadIfNeeded()
            #expect(store.loadState == .failed)
            #expect(!store.canEdit)
            let preserved = try Data(contentsOf: legacyURL)
            #expect(preserved == legacyData)
        }
    }

    private func withCorruptFile(
        test: @MainActor (SamouraiStore, URL) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-recovery-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "projects.json")
        try corruptData.write(to: fileURL)
        let persistence = SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil)
        try await test(SamouraiStore(persistence: persistence), fileURL)
    }
}
