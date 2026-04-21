import Foundation

// MARK: - Module-level utilities

extension Array where Element: Hashable {
    func removingDuplicateValues() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

func normalizeRoleToken(_ value: String) -> String {
    value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Cross-domain projection types

struct RiskEntry: Identifiable, Hashable {
    let projectID: UUID?
    let projectName: String
    let risk: Risk

    var id: UUID { risk.id }
}

struct DeliverableEntry: Identifiable, Hashable {
    let projectID: UUID
    let projectName: String
    let deliverable: Deliverable

    var id: UUID { deliverable.id }
}

struct ScopeCoverageEntry: Identifiable, Hashable {
    let deliverableID: UUID
    let title: String
    let isMilestone: Bool
    let linkedActivityCount: Int

    var id: UUID { deliverableID }
    var isCovered: Bool { isMilestone || linkedActivityCount > 0 }
}

struct ScopeCoverageReport: Hashable {
    let entries: [ScopeCoverageEntry]

    var totalCount: Int { entries.count }
    var coveredCount: Int { entries.filter(\.isCovered).count }
    var coveragePercent: Int {
        guard totalCount > 0 else { return 100 }
        return Int((Double(coveredCount) / Double(totalCount) * 100).rounded())
    }
}

struct ScopeBaselineExecutionProgress: Hashable {
    let baselineLabel: String
    let acceptedCount: Int
    let totalCount: Int

    var progressPercent: Int {
        guard totalCount > 0 else { return 100 }
        return Int((Double(acceptedCount) / Double(totalCount) * 100).rounded())
    }
}
