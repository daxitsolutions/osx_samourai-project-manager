import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct DemoDataTests {
    @Test
    func firstLaunchStaysEmptyUntilExplicitLoadAndPersistsExamples() async throws {
        try await withFile { file in
            let store = makeStore(file)
            #expect(!store.canLoadDemoData)
            #expect(throws: RESTAPIError.self) { try store.loadDemoData() }
            #expect(!FileManager.default.fileExists(atPath: file.path))
            await store.loadIfNeeded()
            #expect(store.canLoadDemoData)
            #expect(store.projects.isEmpty && store.resources.isEmpty)
            try store.loadDemoData()
            #expect(store.projects.count == 2)
            #expect(store.resources.count == 3)
            #expect(store.projects.flatMap(\.risks).count > 0)
            #expect(store.projects.flatMap(\.deliverables).count > 0)
            let ids = Set(store.projects.map(\.id))
            #expect(store.resources.allSatisfy { !$0.assignedProjectIDs.isEmpty && Set($0.assignedProjectIDs).isSubset(of: ids) })
            store.flushSynchronously()
            let disk = try Data(contentsOf: file)
            #expect(!store.canLoadDemoData)
            #expect(throws: RESTAPIError.self) { try store.loadDemoData() }
            #expect(try Data(contentsOf: file) == disk)
            let reloaded = makeStore(file)
            await reloaded.loadIfNeeded()
            #expect(Set(reloaded.projects.map(\.id)) == ids)
            #expect(Set(reloaded.resources.map(\.id)) == Set(store.resources.map(\.id)))
            #expect(!reloaded.canLoadDemoData)
        }
    }

    @Test(arguments: 0..<4)
    func existingDataWithoutProjectsIsNeverReplaced(kind: Int) async throws {
        try await withFile { file in
            var database = SamouraiDatabase.empty
            switch kind {
            case 0: database.resources = Array(SamouraiSeedFactory.makeDemoResources(projects: []).prefix(1))
            case 1: database.unassignedRisks = Array(SamouraiSeedFactory.makeDemoProjects().flatMap(\.risks).prefix(1))
            case 2: database.events = [ProjectEvent(subject: "Fixture")]
            default: database.projects = SamouraiSeedFactory.makeDemoProjects()
            }
            try SamouraiPersistence.makeEncoder().encode(database).write(to: file)
            let store = makeStore(file)
            await store.loadIfNeeded()
            #expect(store.canEdit)
            let before = try SamouraiPersistence.makeEncoder().encode(store.apiDatabaseSnapshot())
            let disk = try Data(contentsOf: file)
            #expect(!store.canLoadDemoData)
            #expect(throws: RESTAPIError.self) { try store.loadDemoData() }
            #expect(try SamouraiPersistence.makeEncoder().encode(store.apiDatabaseSnapshot()) == before)
            #expect(try Data(contentsOf: file) == disk)
        }
    }

    @Test
    func corruptStoreStaysBlockedAndPreservesRejectedFile() async throws {
        try await withFile { file in
            let invalid = Data("invalid-json".utf8)
            try invalid.write(to: file)
            let store = makeStore(file)
            await store.loadIfNeeded()
            #expect(store.loadState == .failed)
            #expect(!store.canLoadDemoData)
            #expect(throws: RESTAPIError.self) { try store.loadDemoData() }
            #expect(try Data(contentsOf: file) == invalid)
            #expect(store.projects.isEmpty && store.resources.isEmpty)
        }
    }

    private func makeStore(_ file: URL) -> SamouraiStore {
        SamouraiStore(persistence: SamouraiPersistence(fileURL: file, migrationSourceURL: nil))
    }

    private func withFile(_ test: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "samourai-demo-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await test(directory.appending(path: "projects.json"))
    }
}
