import Foundation

extension ResourceStore {
    func importResources(_ drafts: [ResourceImportDraft]) -> ResourceImportResult {
        let reviewItems = prepareResourceImportReview(drafts)
        let decisions = reviewItems.map {
            ResourceImportDecision(reviewItemID: $0.id, shouldApply: $0.action == .create || $0.action == .update)
        }
        return applyResourceImportReview(reviewItems, decisions: decisions)
    }

    func prepareResourceImportReviewAsync(
        _ drafts: [ResourceImportDraft],
        reporter: ImportProgressReporter
    ) async throws -> [ResourceImportReviewItem] {
        reporter.setStage(.analyzing)
        reporter.setTotal(drafts.count)
        reporter.setProcessed(0)
        reporter.setImported(0)

        var reviewItems: [ResourceImportReviewItem] = []
        reviewItems.reserveCapacity(drafts.count)
        var earlierRows: [String: ImportBatchEntry] = [:]

        for (index, draft) in inFileOrder(drafts).enumerated() {
            try Task.checkCancellation()
            reviewItems.append(makeResourceImportReviewItem(for: draft, earlierRows: &earlierRows))

            reporter.setProcessed(index + 1)
            if (index + 1) % 10 == 0 || index == drafts.count - 1 {
                await Task.yield()
            }
        }

        return reviewItems
    }

    /// Ordre stable des lignes du fichier : il fixe la règle de cumul des doublons.
    private func inFileOrder(_ drafts: [ResourceImportDraft]) -> [ResourceImportDraft] {
        drafts.enumerated()
            .sorted { ($0.element.sourceRowNumber, $0.offset) < ($1.element.sourceRowNumber, $1.offset) }
            .map(\.element)
    }

    func applyResourceImportReviewAsync(
        _ reviewItems: [ResourceImportReviewItem],
        decisions: [ResourceImportDecision],
        reporter: ImportProgressReporter
    ) async throws -> ResourceImportResult {
        reporter.setStage(.importing)
        reporter.setTotal(reviewItems.count)
        reporter.setProcessed(0)
        reporter.setImported(0)

        let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.reviewItemID, $0.shouldApply) })
        let initialResources = resources
        var batch = ResourceImportBatch(resources: initialResources)

        for (index, item) in reviewItems.enumerated() {
            try Task.checkCancellation()

            batch.apply(item, shouldApply: decisionsByID[item.id] ?? false)

            reporter.setProcessed(index + 1)
            reporter.setImported(batch.importedCount + batch.updatedCount)
            if (index + 1) % 10 == 0 || index == reviewItems.count - 1 {
                await Task.yield()
            }
        }

        reporter.setStage(.finalizing)
        try Task.checkCancellation()
        // Publication en un bloc, sans écraser une modification faite pendant l'import (API, autre vue).
        guard resources == initialResources else {
            throw RESTAPIError.conflict("L'annuaire a été modifié pendant l'import. Aucune ressource n'a été importée ; relance l'import.")
        }
        resources = sortResources(batch.resources)

        return batch.result
    }

    func prepareResourceImportReview(_ drafts: [ResourceImportDraft]) -> [ResourceImportReviewItem] {
        var earlierRows: [String: ImportBatchEntry] = [:]
        return inFileOrder(drafts).map { makeResourceImportReviewItem(for: $0, earlierRows: &earlierRows) }
    }

    func applyResourceImportReview(
        _ reviewItems: [ResourceImportReviewItem],
        decisions: [ResourceImportDecision]
    ) -> ResourceImportResult {
        let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.reviewItemID, $0.shouldApply) })
        var batch = ResourceImportBatch(resources: resources)
        for item in reviewItems {
            batch.apply(item, shouldApply: decisionsByID[item.id] ?? false)
        }
        resources = sortResources(batch.resources)
        return batch.result
    }
}

/// Transformation métier commune ; les adaptateurs décident quand publier le lot.
private struct ResourceImportBatch {
    var resources: [Resource]
    var importedCount = 0
    var updatedCount = 0
    var skippedCount = 0
    var firstID: UUID?

    mutating func apply(_ item: ResourceImportReviewItem, shouldApply: Bool) {
        guard shouldApply, let proposed = item.proposedResource else {
            skippedCount += 1
            return
        }
        switch item.action {
        case .create:
            resources.append(proposed)
            importedCount += 1
        case .update:
            if let index = resources.firstIndex(where: { $0.id == proposed.id }) {
                resources[index] = proposed
                updatedCount += 1
            } else if !item.isExistingResource {
                // La ligne d'origine d'un doublon interne peut avoir été décochée.
                resources.append(proposed)
                importedCount += 1
            } else {
                skippedCount += 1
                return
            }
        case .noChange, .skipped:
            skippedCount += 1
            return
        }
        if firstID == nil { firstID = proposed.id }
    }

    var result: ResourceImportResult {
        ResourceImportResult(importedCount: importedCount, updatedCount: updatedCount,
            skippedCount: skippedCount, firstImportedOrUpdatedResourceID: firstID)
    }
}
