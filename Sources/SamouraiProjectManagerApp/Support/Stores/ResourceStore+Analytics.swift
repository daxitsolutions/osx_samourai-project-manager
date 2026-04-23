import Foundation

extension ResourceStore {
    func resources(for projectID: UUID) -> [Resource] {
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

    func resourceProfiling(for projectID: UUID?) -> ResourceProfilingReport {
        let scopedResources: [Resource]
        if let projectID {
            scopedResources = resources(for: projectID)
        } else {
            scopedResources = resources
        }

        let coverage = CriticalProjectRole.allCases.map { role in
            let assigned = scopedResources
                .filter { $0.criticalRoles.contains(role) }
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return ResourceRoleCoverage(role: role, assignedResources: assigned)
        }

        return ResourceProfilingReport(
            requiredRoles: CriticalProjectRole.allCases,
            roleCoverage: coverage
        )
    }

    @discardableResult
    func addResourceEvaluation(
        resourceID: UUID,
        scopedProjectID: UUID?,
        scopedProjectPhase: ProjectPhase?,
        milestone: String,
        evaluator: String,
        comment: String,
        criterionScores: [ResourceCriterionScore],
        evaluatedAt: Date = .now
    ) -> Bool {
        guard let resourceIndex = resources.firstIndex(where: { $0.id == resourceID }) else { return false }
        let cleanedMilestone = milestone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEvaluator = evaluator.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedComment.isEmpty == false else { return false }

        let evaluation = ResourcePerformanceEvaluation(
            evaluatedAt: evaluatedAt,
            milestone: cleanedMilestone.isEmpty ? "Point de contrôle" : cleanedMilestone,
            evaluator: cleanedEvaluator.isEmpty ? "Chef de Projet" : cleanedEvaluator,
            projectID: scopedProjectID,
            projectPhase: scopedProjectPhase,
            criterionScores: normalizedCriterionScores(criterionScores),
            comment: cleanedComment
        )

        resources[resourceIndex].performanceEvaluations.append(evaluation)
        resources[resourceIndex].performanceEvaluations.sort { $0.evaluatedAt < $1.evaluatedAt }
        resources[resourceIndex].updatedAt = .now
        resources = sortResources(resources)
        return true
    }

    func performanceSnapshot(for resourceID: UUID, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot? {
        guard let resource = resource(with: resourceID) else { return nil }
        return makePerformanceSnapshot(for: resource, scopedProjectID: scopedProjectID)
    }

    func comparativePerformance(for projectID: UUID?) -> [ResourcePerformanceSnapshot] {
        let scopedResources: [Resource]
        if let projectID {
            scopedResources = resources(for: projectID)
        } else {
            scopedResources = resources
        }

        return scopedResources
            .map { makePerformanceSnapshot(for: $0, scopedProjectID: projectID) }
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

    private func normalizedCriterionScores(_ scores: [ResourceCriterionScore]) -> [ResourceCriterionScore] {
        let scoreByCriterion = Dictionary(uniqueKeysWithValues: scores.map { ($0.criterion, $0.score) })
        return ResourceEvaluationCriterion.allCases.map { criterion in
            ResourceCriterionScore(
                criterion: criterion,
                score: scoreByCriterion[criterion] ?? .satisfaisant
            )
        }
    }

    private func scopedEvaluations(for resource: Resource, projectID: UUID?) -> [ResourcePerformanceEvaluation] {
        let sorted = resource.performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        guard let projectID else { return sorted }
        return sorted.filter { $0.projectID == nil || $0.projectID == projectID }
    }

    private func makePerformanceSnapshot(for resource: Resource, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot {
        let allScoped = scopedEvaluations(for: resource, projectID: scopedProjectID)
        let latest = allScoped.last
        let trend = trendForEvaluations(allScoped)
        let groupAverage = groupAverageLatestScore(scopedProjectID: scopedProjectID, excluding: resource.id)
        let alerts = alertsForEvaluations(allScoped, trend: trend, groupAverage: groupAverage)

        return ResourcePerformanceSnapshot(
            resourceID: resource.id,
            resourceName: resource.displayName,
            latestScore: latest?.weightedScore,
            trend: trend,
            alerts: alerts
        )
    }

    private func groupAverageLatestScore(scopedProjectID: UUID?, excluding resourceID: UUID) -> Double? {
        let scoped: [Resource]
        if let scopedProjectID {
            scoped = resources(for: scopedProjectID)
        } else {
            scoped = resources
        }

        let values = scoped
            .filter { $0.id != resourceID }
            .compactMap { resource -> Double? in
                scopedEvaluations(for: resource, projectID: scopedProjectID).last?.weightedScore
            }
        guard values.isEmpty == false else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    private func trendForEvaluations(_ evaluations: [ResourcePerformanceEvaluation]) -> ResourcePerformanceTrend {
        let recent = Array(evaluations.suffix(3))
        guard recent.count >= 2 else { return .stable }
        guard let first = recent.first?.weightedScore, let last = recent.last?.weightedScore else { return .stable }
        let delta = last - first
        if delta <= -0.6 { return .degrading }
        if delta >= 0.6 { return .improving }
        return .stable
    }

    private func alertsForEvaluations(
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
