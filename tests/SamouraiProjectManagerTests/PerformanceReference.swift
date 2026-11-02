// Frozen pre-#58 implementation for regression comparisons.
import Foundation
@testable import SamouraiProjectManagerApp

extension ResourceStore {
    func originalResources(for projectID: UUID) -> [Resource] {
        resources
            .filter { $0.assignedProjectIDs.contains(projectID) }
            .sorted { lhs, rhs in
                let lhsFavorite = lhs.isFavorite(in: projectID)
                let rhsFavorite = rhs.isFavorite(in: projectID)
                if lhsFavorite != rhsFavorite {
                    return lhsFavorite && rhsFavorite == false
                }
                return lhs.fullName.localizedStandardCompare(rhs.fullName) == .orderedAscending
            }
    }

    func originalPerformanceSnapshot(for resourceID: UUID, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot? {
        guard let resource = resource(with: resourceID) else { return nil }
        return originalMakePerformanceSnapshot(for: resource, scopedProjectID: scopedProjectID)
    }

    func originalComparativePerformance(for projectID: UUID?) -> [ResourcePerformanceSnapshot] {
        let scopedResources: [Resource]
        if let projectID {
            scopedResources = originalResources(for: projectID)
        } else {
            scopedResources = resources
        }

        return scopedResources
            .map { originalMakePerformanceSnapshot(for: $0, scopedProjectID: projectID) }
            .sorted { lhs, rhs in
                let lhsRisk = lhs.alerts.isEmpty ? 0 : 1
                let rhsRisk = rhs.alerts.isEmpty ? 0 : 1
                if lhsRisk != rhsRisk { return lhsRisk > rhsRisk }

                switch (lhs.latestScore, rhs.latestScore) {
                case let (.some(left), .some(right)):
                    if left == right {
                        return lhs.resourceName.localizedStandardCompare(rhs.resourceName) == .orderedAscending
                    }
                    return left < right
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return lhs.resourceName.localizedStandardCompare(rhs.resourceName) == .orderedAscending
                }
            }
    }

    fileprivate func originalScopedEvaluations(for resource: Resource, projectID: UUID?) -> [ResourcePerformanceEvaluation] {
        let sorted = resource.performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        guard let projectID else { return sorted }
        return sorted.filter { $0.projectID == nil || $0.projectID == projectID }
    }

    fileprivate func originalMakePerformanceSnapshot(for resource: Resource, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot {
        let allScoped = originalScopedEvaluations(for: resource, projectID: scopedProjectID)
        let latest = allScoped.last
        let trend = originalTrendForEvaluations(allScoped)
        let groupAverage = originalGroupAverageLatestScore(scopedProjectID: scopedProjectID, excluding: resource.id)
        let alerts = originalAlertsForEvaluations(allScoped, trend: trend, groupAverage: groupAverage)

        return ResourcePerformanceSnapshot(
            resourceID: resource.id,
            resourceName: resource.displayName,
            latestScore: latest?.weightedScore,
            trend: trend,
            alerts: alerts
        )
    }

    fileprivate func originalGroupAverageLatestScore(scopedProjectID: UUID?, excluding resourceID: UUID) -> Double? {
        let scoped: [Resource]
        if let scopedProjectID {
            scoped = originalResources(for: scopedProjectID)
        } else {
            scoped = resources
        }

        let values = scoped
            .filter { $0.id != resourceID }
            .compactMap { resource -> Double? in
                originalScopedEvaluations(for: resource, projectID: scopedProjectID).last?.weightedScore
            }
        guard values.isEmpty == false else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    fileprivate func originalTrendForEvaluations(_ evaluations: [ResourcePerformanceEvaluation]) -> ResourcePerformanceTrend {
        let recent = Array(evaluations.suffix(3))
        guard recent.count >= 2 else { return .stable }
        guard let first = recent.first?.weightedScore, let last = recent.last?.weightedScore else { return .stable }
        let delta = last - first
        if delta <= -0.6 { return .degrading }
        if delta >= 0.6 { return .improving }
        return .stable
    }

    fileprivate func originalAlertsForEvaluations(
        _ evaluations: [ResourcePerformanceEvaluation],
        trend: ResourcePerformanceTrend,
        groupAverage: Double?
    ) -> [ResourcePerformanceAlert] {
        guard evaluations.isEmpty == false else { return [] }

        var alerts: [ResourcePerformanceAlert] = []
        if trend == .degrading {
            alerts.append(
                ResourcePerformanceAlert(
                    kind: .sustainedDegradation,
                    message: "La trajectoire des 3 derniers points de contrôle est en baisse."
                )
            )
        }

        if let latest = evaluations.last?.weightedScore, let groupAverage, latest <= groupAverage - 1.0 {
            alerts.append(
                ResourcePerformanceAlert(
                    kind: .belowGroupAverage,
                    message: "La note (\(String(format: "%.2f", latest))/5) est significativement sous la moyenne du groupe (\(String(format: "%.2f", groupAverage))/5)."
                )
            )
        }

        return alerts
    }
}
