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

        for (index, draft) in drafts.enumerated() {
            try Task.checkCancellation()
            reviewItems.append(makeResourceImportReviewItem(for: draft))

            reporter.setProcessed(index + 1)
            if (index + 1) % 10 == 0 || index == drafts.count - 1 {
                await Task.yield()
            }
        }

        return reviewItems.sorted { $0.sourceRowNumber < $1.sourceRowNumber }
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
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        var firstImportedOrUpdatedResourceID: UUID?

        for (index, item) in reviewItems.enumerated() {
            try Task.checkCancellation()

            let shouldApply = decisionsByID[item.id] ?? false

            switch item.action {
            case .create:
                guard shouldApply, let createdResource = item.proposedResource else {
                    skippedCount += 1
                    break
                }
                resources.append(createdResource)
                importedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = createdResource.id
                }
            case .update:
                guard shouldApply, let updatedResource = item.proposedResource else {
                    skippedCount += 1
                    break
                }
                guard let resourceIndex = resources.firstIndex(where: { $0.id == updatedResource.id }) else {
                    skippedCount += 1
                    break
                }
                resources[resourceIndex] = updatedResource
                updatedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = updatedResource.id
                }
            case .noChange, .skipped:
                skippedCount += 1
            }

            reporter.setProcessed(index + 1)
            reporter.setImported(importedCount + updatedCount)
            if (index + 1) % 10 == 0 || index == reviewItems.count - 1 {
                await Task.yield()
            }
        }

        reporter.setStage(.finalizing)
        resources = sortResources(resources)

        return ResourceImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount,
            firstImportedOrUpdatedResourceID: firstImportedOrUpdatedResourceID
        )
    }

    func prepareResourceImportReview(_ drafts: [ResourceImportDraft]) -> [ResourceImportReviewItem] {
        let reviewItems = drafts.map { makeResourceImportReviewItem(for: $0) }
        return reviewItems.sorted { $0.sourceRowNumber < $1.sourceRowNumber }
    }

    func applyResourceImportReview(
        _ reviewItems: [ResourceImportReviewItem],
        decisions: [ResourceImportDecision]
    ) -> ResourceImportResult {
        let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.reviewItemID, $0.shouldApply) })
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        var firstImportedOrUpdatedResourceID: UUID?

        for item in reviewItems {
            let shouldApply = decisionsByID[item.id] ?? false

            switch item.action {
            case .create:
                guard shouldApply, let createdResource = item.proposedResource else {
                    skippedCount += 1
                    continue
                }

                resources.append(createdResource)
                importedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = createdResource.id
                }
            case .update:
                guard shouldApply, let updatedResource = item.proposedResource else {
                    skippedCount += 1
                    continue
                }

                guard let index = resources.firstIndex(where: { $0.id == updatedResource.id }) else {
                    skippedCount += 1
                    continue
                }

                resources[index] = updatedResource
                updatedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = updatedResource.id
                }
            case .noChange, .skipped:
                skippedCount += 1
            }
        }

        resources = sortResources(resources)

        return ResourceImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount,
            firstImportedOrUpdatedResourceID: firstImportedOrUpdatedResourceID
        )
    }

}
