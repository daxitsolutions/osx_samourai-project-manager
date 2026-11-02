import Foundation
import Testing
@testable import SamouraiProjectManagerApp

@MainActor
struct ResourcePerformanceTests {
    private func evaluation(_ score: ResourceEvaluationScale, day: Int, project: UUID? = nil) -> ResourcePerformanceEvaluation {
        ResourcePerformanceEvaluation(evaluatedAt: Date(timeIntervalSince1970: Double(day * 86400)),
            milestone: "Synthetic", evaluator: "Fixture", projectID: project, projectPhase: nil,
            criterionScores: ResourceEvaluationCriterion.allCases.map { .init(criterion: $0, score: score) }, comment: "Fixture")
    }
    private func resource(_ name: String, projects: [UUID], evaluations: [ResourcePerformanceEvaluation]) -> Resource {
        Resource(fullName: name, jobTitle: "", department: "", email: "", phone: "",
            engagement: .internalEmployee, status: .active, allocationPercent: 100,
            assignedProjectIDs: projects, performanceEvaluations: evaluations, notes: "")
    }
    private func assertEqual(_ actual: ResourcePerformanceSnapshot?, _ expected: ResourcePerformanceSnapshot?) {
        #expect(actual?.resourceID == expected?.resourceID)
        #expect(actual?.resourceName == expected?.resourceName)
        #expect(actual?.latestScore == expected?.latestScore)
        #expect(actual?.trend == expected?.trend)
        // Alert IDs are intentionally random; compare their visible content and order.
        #expect(actual?.alerts.map(\.kind) == expected?.alerts.map(\.kind))
        #expect(actual?.alerts.map(\.message) == expected?.alerts.map(\.message))
    }
    @Test func preservesScopesTrendsAlertsAndMissingScores() {
        let p = UUID(), q = UUID(), store = ResourceStore()
        let descending = [evaluation(.expert, day: 1), evaluation(.solide, day: 2), evaluation(.lacunaire, day: 3)]
        store.resources = [
            resource("Degrading", projects: [p], evaluations: descending.reversed()),
            resource("Improving", projects: [p,q], evaluations: [evaluation(.lacunaire, day: 1), evaluation(.solide, day: 2), evaluation(.expert, day: 3)]),
            resource("No score", projects: [p], evaluations: []),
            resource("Global peer", projects: [p], evaluations: [evaluation(.expert, day: 1)]),
            resource("Other project", projects: [q], evaluations: [evaluation(.lacunaire, day: 1, project: q)]),
            resource("Scoped histories", projects: [p,q], evaluations: [evaluation(.solide, day: 3, project: q), evaluation(.fragile, day: 2, project: p), evaluation(.expert, day: 1)]),
            resource("Unassigned", projects: [], evaluations: descending)
        ]
        for scope in [nil, p, q, UUID()] as [UUID?] {
            let actual = store.comparativePerformance(for: scope)
            let expected = store.originalComparativePerformance(for: scope)
            #expect(actual.count == expected.count)
            for (a,e) in zip(actual, expected) { assertEqual(a,e) }
            for r in store.resources {
                assertEqual(store.performanceSnapshot(for: r.id, scopedProjectID: scope),
                    store.originalPerformanceSnapshot(for: r.id, scopedProjectID: scope))
            }
        }
        #expect(store.performanceSnapshot(for: UUID(), scopedProjectID: nil) == nil)
        let degrading = store.performanceSnapshot(for: store.resources[0].id, scopedProjectID: p)
        #expect(degrading?.trend == .degrading)
        #expect(degrading?.alerts.map(\.kind) == [.sustainedDegradation, .belowGroupAverage])
    }
    @Test func emptySingletonTiesAndMutation() {
        let store = ResourceStore(), p = UUID()
        #expect(store.comparativePerformance(for: nil).isEmpty)
        var r = resource("One", projects: [p], evaluations: [evaluation(.fragile, day: 1)])
        store.resources = [r]
        assertEqual(store.performanceSnapshot(for: r.id, scopedProjectID: p), store.originalPerformanceSnapshot(for: r.id, scopedProjectID: p))
        #expect(store.performanceSnapshot(for: r.id, scopedProjectID: p)?.alerts.isEmpty == true)
        r.performanceEvaluations = [evaluation(.lacunaire, day: 1), evaluation(.expert, day: 1)]
        store.resources = [r, resource("Peer", projects: [p], evaluations: [evaluation(.expert, day: 1)])]
        assertEqual(store.performanceSnapshot(for: r.id, scopedProjectID: p), store.originalPerformanceSnapshot(for: r.id, scopedProjectID: p))
        r.performanceEvaluations = [evaluation(.lacunaire, day: 2)]
        store.resources[0] = r
        assertEqual(store.performanceSnapshot(for: r.id, scopedProjectID: p), store.originalPerformanceSnapshot(for: r.id, scopedProjectID: p))
        #expect(store.performanceSnapshot(for: r.id, scopedProjectID: p)?.alerts.map(\.kind) == [.belowGroupAverage])
    }
    @Test func measureLargeGroupsAgainstOriginal() {
        for count in [1_000, 3_000] {
            let store = ResourceStore()
            store.resources = (0..<count).map { i in
                resource("Person \(i)", projects: [], evaluations: [evaluation(.solide, day: 3), evaluation(.fragile, day: 1), evaluation(i.isMultiple(of: 2) ? .expert : .lacunaire, day: 2)])
            }
            let clock = ContinuousClock(), start = clock.now
            let expected = store.originalComparativePerformance(for: nil)
            let old = clock.now - start, next = clock.now
            let actual = store.comparativePerformance(for: nil)
            let new = clock.now - next
            #expect(actual.count == expected.count)
            for (a,e) in zip(actual,expected) { assertEqual(a,e) }
            print("[#58] count=\(count) original=\(old) aggregate=\(new)")
        }
    }
}
