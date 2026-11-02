import Foundation
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #37 : une annulation ou une modification concurrente ne laisse aucun import partiel.
@MainActor
struct ImportCancellationTests {
    enum CancelPoint: String, CaseIterable {
        case beforeProcessing, midBatch, finalizing
    }

    @Test(arguments: CancelPoint.allCases)
    func cancelledResourceImportLeavesDirectoryUntouched(at point: CancelPoint) async throws {
        try await withStore { store, fileURL in
            _ = store.importResources([resourceDraft(0)])
            store.flushSynchronously()
            let before = store.resources
            let saved = try Data(contentsOf: fileURL)
            let review = store.prepareResourceImportReview((1...20).map(resourceDraft))
            let decisions = review.map { ResourceImportDecision(reviewItemID: $0.id, shouldApply: true) }

            let outcome = await run(cancelAt: point) { reporter in
                try await store.applyResourceImportReviewAsync(review, decisions: decisions, reporter: reporter)
            }
            #expect(outcome is CancellationError)
            #expect(store.resources == before)
            store.flushSynchronously()
            #expect(try Data(contentsOf: fileURL) == saved)
        }
    }

    @Test(arguments: CancelPoint.allCases)
    func cancelledRiskImportLeavesRisksUntouched(at point: CancelPoint) async throws {
        try await withStore { store, fileURL in
            _ = store.importRisks([riskDraft(0)])
            store.flushSynchronously()
            let before = (store.projects, store.apiRiskRecords().map(\.risk))
            let saved = try Data(contentsOf: fileURL)

            let outcome = await run(cancelAt: point) { reporter in
                try await store.importRisksAsync((1...20).map(riskDraft), reporter: reporter)
            }
            #expect(outcome is CancellationError)
            #expect(store.projects == before.0)
            #expect(store.apiRiskRecords().map(\.risk) == before.1)
            store.flushSynchronously()
            #expect(try Data(contentsOf: fileURL) == saved)
        }
    }

    @Test
    func uncancelledImportsPublishEveryItem() async throws {
        try await withStore { store, _ in
            let review = store.prepareResourceImportReview((1...20).map(resourceDraft))
            let decisions = review.map { ResourceImportDecision(reviewItemID: $0.id, shouldApply: true) }
            let resources = try await store.applyResourceImportReviewAsync(review, decisions: decisions, reporter: .noop)
            let risks = try await store.importRisksAsync((1...20).map(riskDraft), reporter: .noop)
            #expect(resources.importedCount == 20)
            #expect(store.resources.count == 20)
            #expect(risks.importedCount == 20)
            #expect(store.apiRiskRecords().count == 20)
        }
    }

    @Test
    func concurrentChangeDuringImportIsKeptAndNothingIsPublished() async throws {
        try await withStore { store, _ in
            _ = store.importResources([resourceDraft(0)])
            _ = store.importRisks([riskDraft(0)])
            let resourceID = try #require(store.resources.first?.id)
            let riskID = try #require(store.apiRiskRecords().first?.risk.id)
            let review = store.prepareResourceImportReview((1...20).map(resourceDraft))
            let decisions = review.map { ResourceImportDecision(reviewItemID: $0.id, shouldApply: true) }

            // Une écriture API survient pendant le lot : elle doit survivre et l'import être refusé en bloc.
            let resourceOutcome = await run(onMidBatch: { try? store.apiDeleteResource(id: resourceID) }) { reporter in
                try await store.applyResourceImportReviewAsync(review, decisions: decisions, reporter: reporter)
            }
            #expect((resourceOutcome as? RESTAPIError)?.statusCode == 409)
            #expect(store.resources.isEmpty)

            let riskOutcome = await run(onMidBatch: { store.deleteRisk(riskID: riskID) }) { reporter in
                try await store.importRisksAsync((1...20).map(riskDraft), reporter: reporter)
            }
            #expect((riskOutcome as? RESTAPIError)?.statusCode == 409)
            #expect(store.apiRiskRecords().isEmpty)
        }
    }

    // MARK: - Banc

    /// Lance l'import dans une tâche et l'annule au point demandé ; renvoie l'erreur levée (nil si succès).
    private func run<T: Sendable>(
        cancelAt point: CancelPoint? = nil,
        onMidBatch: (@MainActor @Sendable () -> Void)? = nil,
        _ operation: @escaping @MainActor @Sendable (ImportProgressReporter) async throws -> T
    ) async -> Error? {
        let box = TaskBox()
        let reporter = ImportProgressReporter(
            setStage: { stage in
                if stage == .finalizing, point == .finalizing { box.task?.cancel() }
            },
            setTotal: { _ in },
            setProcessed: { processed in
                guard processed == 10 else { return }
                if point == .midBatch { box.task?.cancel() }
                MainActor.assumeIsolated { onMidBatch?() }
            },
            setImported: { _ in }
        )
        let task = Task { @MainActor in _ = try await operation(reporter) }
        box.task = task
        if point == .beforeProcessing { task.cancel() }
        do {
            try await task.value
            return nil
        } catch {
            return error
        }
    }

    private final class TaskBox: @unchecked Sendable {
        var task: Task<Void, Error>?
    }

    private func resourceDraft(_ index: Int) -> ResourceImportDraft {
        ResourceImportDraft(
            nom: "Personne \(index)", prenom: nil, nomDeFamille: nil, parentDescription: nil,
            primaryResourceRole: nil, resourceRoles: nil, organizationalResource: nil, competence1: nil,
            resourceCalendar: nil, resourceStartDate: nil, resourceFinishDate: nil, responsableOperationnel: nil,
            responsableInterne: nil, localisation: nil, typeDeRessource: nil, journeesTempsPartiel: nil,
            email: "personne\(index)@example.test", phone: nil, engagement: .internalEmployee, status: .active,
            allocationPercent: 100, notes: "", sourceRowNumber: index + 1
        )
    }

    private func riskDraft(_ index: Int) -> RiskImportDraft {
        RiskImportDraft(externalID: "R-\(index)", projectNames: nil, detectedBy: nil, assignedTo: nil,
            dateCreated: nil, lastModifiedAt: nil, riskType: nil, response: nil, riskTitle: "Risque \(index)",
            riskOrigin: nil, impactDescription: nil, counterMeasure: nil, followUpComment: nil,
            proximity: nil, probability: nil, impactScope: nil, impactBudget: nil, impactPlanning: nil,
            impactResources: nil, impactTransition: nil, impactSecurityIT: nil, escalationLevel: nil,
            riskStatus: nil, score0to10: nil, sourceRowNumber: index + 1)
    }

    private func withStore(test: (SamouraiStore, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "samourai-import-cancel-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appending(path: "projects.json")
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil))
        await store.loadIfNeeded()
        store.flushSynchronously()
        try await test(store, fileURL)
        store.flushSynchronously()
    }
}
