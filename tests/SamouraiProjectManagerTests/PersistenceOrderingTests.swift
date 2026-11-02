import Foundation
import Testing
@testable import SamouraiProjectManagerApp

struct PersistenceOrderingTests {
    @Test
    func burstCoalescesAndFlushPreventsLateOverwrite() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "projects.json")
        let writer = SamouraiPersistenceWriter(fileURL: file, debounceInterval: 0.3)
        var database = fixture("initial")
        let start = ContinuousClock.now
        for index in 0..<1_000 {
            database.projects[0].name = "Mutation \(index)"
            writer.schedule(database) { error in Issue.record("Unexpected save failure: \(error)") }
        }
        database.projects[0].name = "État final"
        try writer.flush(database)
        let latency = start.duration(to: .now)
        #expect(try read(file).projects[0].name == "État final")
        try await Task.sleep(for: .milliseconds(500))
        #expect(try read(file).projects[0].name == "État final")
        #expect(writer.completedWriteCount == 1)
        #expect(try backups(root).count == 1)
        print("1,000 scheduled mutations + immediate flush: \(writer.completedWriteCount) primary write, latency \(latency)")
    }

    @Test
    func deferredSaveWritesLatestSnapshotWithoutFlush() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "projects.json")
        let writer = SamouraiPersistenceWriter(fileURL: file, debounceInterval: 0.1)
        writer.schedule(fixture("ancien")) { Issue.record("Unexpected save failure: \($0)") }
        writer.schedule(fixture("récent")) { Issue.record("Unexpected save failure: \($0)") }
        // Bounded polling asserts observed execution, not merely a scheduled command.
        for _ in 0..<100 {
            if writer.completedWriteCount > 0 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(try read(file).projects[0].name == "récent")
        #expect(writer.completedWriteCount == 1)
    }

    @Test
    func backupFrequencyIsIndependentAndRetentionStillApplies() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "projects.json")
        let writer = SamouraiPersistenceWriter(fileURL: file, backupInterval: 60)
        for index in 0..<20 { try writer.flush(fixture("\(index)")) }
        #expect(writer.completedWriteCount == 20)
        #expect(try backups(root).count == 1)
        let timed = SamouraiPersistenceWriter(fileURL: file, backupInterval: 0.1)
        try timed.flush(fixture("nouvelle session"))
        try await Task.sleep(for: .milliseconds(150))
        try timed.flush(fixture("après intervalle"))
        #expect(try backups(root).count == 3)
        #expect(try read(file).projects[0].name == "après intervalle")
        let retention = SamouraiPersistenceWriter(fileURL: file, backupInterval: 0)
        for _ in 0..<121 { try retention.flush(.empty) }
        #expect(try backups(root).count == 120)
    }

    @Test
    func diskFailureIsReportedAndCanBeRetried() async throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appending(path: "blocked")
        try Data("original".utf8).write(to: blocker)
        let writer = SamouraiPersistenceWriter(fileURL: blocker.appending(path: "projects.json"), debounceInterval: 0)
        await confirmation("asynchronous disk error delivered") { confirmation in
            writer.schedule(.empty) { _ in confirmation() }
            // A sync count read is a barrier after the scheduling block, but the
            // delayed write may still be waiting, so await the observed callback.
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(throws: (any Error).self) { try writer.flush(.empty) }
        #expect(try Data(contentsOf: blocker) == Data("original".utf8))
        #expect(writer.completedWriteCount == 0)
        try FileManager.default.removeItem(at: blocker)
        try writer.flush(fixture("réessai"))
        #expect(try read(blocker.appending(path: "projects.json")).projects[0].name == "réessai")
    }

    @Test @MainActor
    func storeFlushAndRestoreCannotBeOverwrittenByPendingMutations() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "projects.json")
        let persistence = SamouraiPersistence(fileURL: file, migrationSourceURL: nil)
        let store = SamouraiStore(persistence: persistence)
        await store.loadIfNeeded()
        for index in 0..<100 { try store.apiReplaceDatabase(fixture("\(index)")) }
        store.flushSynchronously()
        #expect(try read(file).projects[0].name == "99")
        try store.apiReplaceDatabase(fixture("capture périmée"))
        let envelope = SamouraiBackupEnvelope(appVersion: "test", database: fixture("restauré"))
        _ = try store.restoreBackupData(SamouraiPersistence.makeEncoder().encode(envelope))
        try await Task.sleep(for: .milliseconds(400))
        #expect(try read(file).projects[0].name == "restauré")
        #expect(store.projects[0].name == "restauré")
        #expect(persistence.writer.completedWriteCount == 2)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "samourai-persistence-\(UUID())")
    }
    private func fixture(_ name: String) -> SamouraiDatabase {
        var projects = SamouraiSeedFactory.makeDemoProjects()
        projects[0].name = name
        return SamouraiDatabase(projects: projects, resources: [])
    }
    private func read(_ file: URL) throws -> SamouraiDatabase {
        try SamouraiPersistence.makeDecoder().decode(SamouraiDatabase.self, from: Data(contentsOf: file))
    }
    private func backups(_ root: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root.appending(path: "auto-backups"), includingPropertiesForKeys: nil)
    }
}
