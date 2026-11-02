import Foundation
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #38 : les doublons internes à un fichier d'import ne créent qu'une ressource,
/// sont signalés dans la revue et produisent un résultat déterministe.
@MainActor
struct ResourceImportDuplicateTests {
    @Test(arguments: [false, true])
    func identicalRowsCreateASingleResource(asynchronous: Bool) async throws {
        try await withStore { store in
            let review = try await prepare([draft(row: 2), draft(row: 3)], store: store, asynchronous: asynchronous)
            #expect(review.map(\.action) == [.create, .noChange])
            #expect(review.map(\.duplicateOfRowNumber) == [nil, 2])

            let result = try await apply(review, store: store, asynchronous: asynchronous)
            #expect(result.importedCount == 1)
            #expect(store.resources.count == 1)
            #expect(store.resources.first?.email == "alice@example.test")
        }
    }

    @Test(arguments: [false, true])
    func laterRowsCompleteTheResourceCreatedByTheFirstRow(asynchronous: Bool) async throws {
        try await withStore { store in
            let review = try await prepare(
                [draft(row: 2, phone: "01"), draft(row: 3, phone: "02"), draft(row: 4, phone: nil)],
                store: store, asynchronous: asynchronous
            )
            #expect(review.map(\.action) == [.create, .update, .noChange])
            #expect(review.map(\.duplicateOfRowNumber) == [nil, 2, 2])
            #expect(Set(review.compactMap(\.resourceID)).count == 1)

            _ = try await apply(review, store: store, asynchronous: asynchronous)
            #expect(store.resources.count == 1)
            #expect(store.resources.first?.phone == "02")
        }
    }

    @Test(arguments: [false, true])
    func duplicateStillCreatesTheResourceWhenTheFirstRowIsDeclined(asynchronous: Bool) async throws {
        try await withStore { store in
            let review = try await prepare([draft(row: 2, phone: "01"), draft(row: 3, phone: "02")], store: store, asynchronous: asynchronous)
            let result = try await apply(review, store: store, asynchronous: asynchronous, declining: [2])
            #expect(result.importedCount == 1)
            #expect(store.resources.count == 1)
            #expect(store.resources.first?.phone == "02")
        }
    }

    @Test(arguments: [false, true])
    func repeatedUpdatesOfAnExistingResourceAreDeterministic(asynchronous: Bool) async throws {
        try await withStore { store in
            _ = store.importResources([draft(row: 1, phone: "00")])
            let existingID = try #require(store.resources.first?.id)
            let rows = [draft(row: 2, phone: "01"), draft(row: 3, phone: "02")]

            // L'ordre de lecture n'influe pas : seul le numéro de ligne fixe le cumul.
            let review = try await prepare(rows.reversed(), store: store, asynchronous: asynchronous)
            #expect(review.map(\.sourceRowNumber) == [2, 3])
            #expect(review.map(\.action) == [.update, .update])
            #expect(review.allSatisfy { $0.resourceID == existingID && $0.isExistingResource })
            #expect(review.map(\.duplicateOfRowNumber) == [nil, 2])

            let result = try await apply(review, store: store, asynchronous: asynchronous)
            #expect(result.importedCount == 0)
            #expect(store.resources.count == 1)
            #expect(store.resources.first?.id == existingID)
            #expect(store.resources.first?.phone == "02")
        }
    }

    @Test
    func syncAndAsyncApplyTheSameReviewAndDecisionsIdentically() async throws {
        try await withStore { syncStore in
            try await withStore { asyncStore in
                let review = syncStore.prepareResourceImportReview([
                    draft(row: 2, phone: "01"), draft(row: 3, phone: "02"),
                    draft(row: 4, phone: "03"), draft(row: 5, phone: nil)
                ])
                let sync = try await apply(review, store: syncStore, asynchronous: false, declining: [2])
                let async = try await apply(review, store: asyncStore, asynchronous: true, declining: [2])
                #expect(syncStore.resources == asyncStore.resources)
                #expect(sync.importedCount == 1)
                #expect(sync.updatedCount == 1)
                #expect(sync.skippedCount == 2)
                #expect(sync.importedCount == async.importedCount)
                #expect(sync.updatedCount == async.updatedCount)
                #expect(sync.skippedCount == async.skippedCount)
                #expect(sync.firstImportedOrUpdatedResourceID == async.firstImportedOrUpdatedResourceID)
                #expect(syncStore.resources.first?.phone == "03")
            }
        }
    }

    // MARK: - Banc

    private func prepare(_ drafts: [ResourceImportDraft], store: SamouraiStore, asynchronous: Bool) async throws -> [ResourceImportReviewItem] {
        if asynchronous { return try await store.prepareResourceImportReviewAsync(drafts, reporter: .noop) }
        return store.prepareResourceImportReview(drafts)
    }

    /// Applique les décisions par défaut de la revue (créations et mises à jour cochées), sauf les lignes refusées.
    private func apply(
        _ review: [ResourceImportReviewItem],
        store: SamouraiStore,
        asynchronous: Bool,
        declining declinedRows: Set<Int> = []
    ) async throws -> ResourceImportResult {
        let decisions = review.map {
            ResourceImportDecision(
                reviewItemID: $0.id,
                shouldApply: ($0.action == .create || $0.action == .update) && !declinedRows.contains($0.sourceRowNumber)
            )
        }
        if asynchronous { return try await store.applyResourceImportReviewAsync(review, decisions: decisions, reporter: .noop) }
        return store.applyResourceImportReview(review, decisions: decisions)
    }

    private func draft(row: Int, phone: String? = nil) -> ResourceImportDraft {
        ResourceImportDraft(
            nom: "Alice", prenom: nil, nomDeFamille: nil, parentDescription: nil,
            primaryResourceRole: nil, resourceRoles: nil, organizationalResource: nil, competence1: nil,
            resourceCalendar: nil, resourceStartDate: nil, resourceFinishDate: nil, responsableOperationnel: nil,
            responsableInterne: nil, localisation: nil, typeDeRessource: nil, journeesTempsPartiel: nil,
            email: "alice@example.test", phone: phone, engagement: .internalEmployee, status: .active,
            allocationPercent: 100, notes: "", sourceRowNumber: row
        )
    }

    private func withStore(test: (SamouraiStore) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "samourai-resource-duplicates-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: root.appending(path: "projects.json"), migrationSourceURL: nil))
        await store.loadIfNeeded()
        try await test(store)
        store.flushSynchronously()
    }
}
