import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct RiskImportTests {
    @Test(arguments: [false, true], [false, true])
    func reimportPreservesIdentityHistoryAndMissingFields(inProject: Bool, asynchronous: Bool) async throws {
        try await withStore(inProject: inProject) { store, fileURL in
            let originalDraft = draft(project: inProject ? "Projet test" : nil)
            let first = try await runImport([originalDraft], store: store, asynchronous: asynchronous)
            let id = try #require(first.firstImportedOrUpdatedRiskID)
            #expect(store.addRiskComment(riskID: id, text: "Commentaire à conserver"))
            let dueDate = Date(timeIntervalSince1970: 2_000_000_000)
            store.updateRisk(riskID: id, title: "Risque test", mitigation: "Action locale", owner: "Responsable local", severity: .critical, dueDate: dueDate, status: .toDo)
            var local = try #require(store.apiRiskRecords().first { $0.risk.id == id })
            local.risk.followUpComment = "Suivi local"
            local.risk.riskOrigin = "Origine locale"
            local.risk.probability = "Faible"
            local.risk.detectedBy = "Équipe locale"
            _ = try store.apiUpsertRisk(local, replacing: id)
            let before = try #require(risk(id, in: store))
            let result = try await runImport([originalDraft], store: store, asynchronous: asynchronous)
            let after = try #require(risk(id, in: store))
            #expect(result.importedCount == 0)
            #expect(result.updatedCount == 1)
            #expect(result.firstImportedOrUpdatedRiskID == id)
            #expect(after == before)
            store.flushSynchronously()
            let saved = try SamouraiPersistence.makeDecoder().decode(SamouraiDatabase.self, from: Data(contentsOf: fileURL))
            let persisted = (saved.unassignedRisks + saved.projects.flatMap(\.risks)).first { $0.id == id }
            // Le format JSON existant encode les dates ISO-8601 à la seconde.
            let expectedOnDisk = try SamouraiPersistence.makeDecoder().decode(
                Risk.self, from: SamouraiPersistence.makeEncoder().encode(after)
            )
            #expect(persisted == expectedOnDisk)
        }
    }

    @Test(arguments: [false, true])
    func changedImportedFieldsAreRecordedWithoutRemovingComments(asynchronous: Bool) async throws {
        try await withStore(inProject: false) { store, _ in
            let first = try await runImport([draft()], store: store, asynchronous: asynchronous)
            let id = try #require(first.firstImportedOrUpdatedRiskID)
            #expect(store.addRiskComment(riskID: id, text: "Commentaire intermédiaire"))
            let before = try #require(risk(id, in: store))
            let result = try await runImport([draft(owner: "Nouvelle personne", mitigation: "Nouvelle action", score: 9, origin: "Nouvelle origine")], store: store, asynchronous: asynchronous)
            let after = try #require(risk(id, in: store))
            #expect(result.firstImportedOrUpdatedRiskID == id)
            #expect(after.owner == "Nouvelle personne")
            #expect(after.assignedTo == "Nouvelle personne")
            #expect(after.mitigation == "Nouvelle action")
            #expect(after.counterMeasure == "Nouvelle action")
            #expect(after.severity == .critical)
            #expect(after.score0to10 == 9)
            #expect(after.riskOrigin == "Nouvelle origine")
            #expect(Array(after.historyEntries.prefix(before.historyEntries.count)) == before.historyEntries)
            #expect(after.historyEntries.count > before.historyEntries.count)
            #expect(after.historyEntries.last?.kind == .automatic)
            #expect(after.historyEntries.last?.text.contains("Nouvelle origine") == true)
            _ = try await runImport([draft(owner: "Nouvelle personne", mitigation: "Nouvelle action", score: 9, origin: "Nouvelle origine")], store: store, asynchronous: asynchronous)
            #expect(risk(id, in: store) == after)
        }
    }

    @Test
    func whitespaceCellsPreserveLocalValuesAndDistinctRisksStayDistinct() async throws {
        try await withStore(inProject: false) { store, _ in
            _ = store.importRisks([draft(owner: "Personne", mitigation: "Action", score: 8, origin: "Origine")])
            let before = try #require(store.unassignedRisks.first)
            _ = store.importRisks([draft(owner: "  ", mitigation: "\n", origin: "\t")])
            #expect(store.unassignedRisks.first == before)
            _ = store.importRisks([draft(externalID: "autre")])
            #expect(store.unassignedRisks.count == 2)
            #expect(Set(store.unassignedRisks.map(\.id)).count == 2)
        }
    }

    private func risk(_ id: UUID, in store: SamouraiStore) -> Risk? {
        (store.unassignedRisks + store.projects.flatMap(\.risks)).first { $0.id == id }
    }

    private func runImport(_ drafts: [RiskImportDraft], store: SamouraiStore, asynchronous: Bool) async throws -> RiskImportResult {
        if asynchronous { return try await store.importRisksAsync(drafts, reporter: .noop) }
        return store.importRisks(drafts)
    }

    private func draft(externalID: String = "R-1", project: String? = nil, owner: String? = nil, mitigation: String? = nil, score: Double? = nil, origin: String? = nil) -> RiskImportDraft {
        RiskImportDraft(externalID: externalID, projectNames: project, detectedBy: nil, assignedTo: owner,
            dateCreated: nil, lastModifiedAt: nil, riskType: nil, response: nil, riskTitle: "Risque test",
            riskOrigin: origin, impactDescription: nil, counterMeasure: mitigation, followUpComment: nil,
            proximity: nil, probability: nil, impactScope: nil, impactBudget: nil, impactPlanning: nil,
            impactResources: nil, impactTransition: nil, impactSecurityIT: nil, escalationLevel: nil,
            riskStatus: nil, score0to10: score, sourceRowNumber: 2)
    }

    private func withStore(inProject: Bool, test: (SamouraiStore, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "samourai-risk-import-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appending(path: "projects.json")
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: fileURL, migrationSourceURL: nil))
        await store.loadIfNeeded()
        if inProject {
            _ = store.addProject(name: "Projet test", summary: "", sponsor: "", manager: "", phase: .cadrage,
                health: .green, deliveryMode: .waterfall, startDate: .now, targetDate: .now)
        }
        try await test(store, fileURL)
        store.flushSynchronously()
    }
}
