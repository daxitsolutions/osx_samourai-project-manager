import Foundation
import Testing
@testable import SamouraiProjectManagerApp

struct ActivityIndexTests {
    @Test
    func normalizationPreservesLegacyResultsAndInvalidLinks() {
        let (projects, activities) = fixture(count: 300)
        let expected = reference(activities, projects: projects)
        let actual = ActivityNormalizer.normalize(activities, projects: projects)
        #expect(actual == expected)
        #expect(actual.count == activities.count - 1)
        #expect(actual[0].parentActivityID == nil) // cycle member
        #expect(actual[1].parentActivityID == nil) // invalid hierarchy
        #expect(actual[2].parentActivityID == nil) // cycle member
        #expect(actual[3].parentActivityID == activities[0].id) // leads into cycle, legacy behavior
        #expect(actual.allSatisfy { $0.isDateless || $0.estimatedEndDate >= $0.estimatedStartDate })
    }

    @Test
    func longRawParentChainsAndCyclesMatchReference() {
        let (projects, input) = fixture(count: 1_000)
        var activities = Array(input.dropLast())
        for n in activities.indices {
            activities[n].projectID = projects[0].id
            activities[n].scenarioID = projects[0].defaultPlanningScenarioID
            activities[n].hierarchyLevel = n % 2 == 0 ? .mainDeliverable : .activityTask
            activities[n].parentActivityID = n + 1 < activities.count ? activities[n + 1].id : nil
        }
        #expect(ActivityNormalizer.normalize(activities, projects: projects) == reference(activities, projects: projects))
        activities[activities.count - 1].parentActivityID = activities[400].id
        #expect(ActivityNormalizer.normalize(activities, projects: projects) == reference(activities, projects: projects))
        activities[0].parentActivityID = activities[0].id
        activities[1].parentActivityID = UUID()
        #expect(ActivityNormalizer.normalize(activities, projects: projects) == reference(activities, projects: projects))
    }

    @Test
    func childIndexPreservesDisplayOrderMilestonesAndRoots() {
        let (_, activities) = fixture(count: 600)
        for milestonesAsRoots in [false, true] {
            let index = ActivityTreeIndex(activities, milestonesAsRoots: milestonesAsRoots)
            let roots = activities.filter {
                milestonesAsRoots ? ($0.parentActivityID == nil || $0.isMilestone) : ($0.parentActivityID == nil && !$0.isMilestone)
            }.sorted(by: ProjectActivity.planningDisplayOrderPrecedes)
            #expect(index.roots == roots)
            for activity in activities {
                let expected = activities.filter { $0.parentActivityID == activity.id && !$0.isMilestone }
                    .sorted(by: ProjectActivity.planningDisplayOrderPrecedes)
                #expect(index.children(of: activity.id) == expected)
            }
            #expect(index.children(of: UUID()).isEmpty)
        }
    }

    @Test
    func largeBatchesMatchReferenceAndMeasureBothAlgorithms() {
        for count in [1_000, 5_000] {
            let (projects, activities) = fixture(count: count)
            let start = ContinuousClock.now
            let expected = reference(activities, projects: projects)
            let legacyTime = start.duration(to: .now)
            let indexedStart = ContinuousClock.now
            let actual = ActivityNormalizer.normalize(activities, projects: projects)
            let indexedTime = indexedStart.duration(to: .now)
            #expect(actual == expected)
            let treeStart = ContinuousClock.now
            let index = ActivityTreeIndex(actual)
            let indexedChildren = actual.map { index.children(of: $0.id).map(\.id) }
            let treeTime = treeStart.duration(to: .now)
            let scanStart = ContinuousClock.now
            let scannedChildren = actual.map { parent in
                actual.filter { $0.parentActivityID == parent.id && !$0.isMilestone }
                    .sorted(by: ProjectActivity.planningDisplayOrderPrecedes).map(\.id)
            }
            let scanTime = scanStart.duration(to: .now)
            #expect(indexedChildren == scannedChildren)
            print("Activities \(count): normalize legacy=\(legacyTime), indexed=\(indexedTime); children scans=\(scanTime), indexed including build=\(treeTime)")
        }
    }

    private func fixture(count: Int) -> ([Project], [ProjectActivity]) {
        var projects = SamouraiSeedFactory.makeDemoProjects()
        for n in projects.indices {
            projects[n].planningScenarios.append(ProjectPlanningScenario(name: "Alternative", createdAt: Date(timeIntervalSince1970: 2_000_000_000)))
        }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var activities = (0..<count).map { n in
            let project = projects[n % projects.count]
            return ProjectActivity(projectID: project.id,
                scenarioID: n % 7 == 0 ? UUID() : (n % 5 == 0 ? project.orderedPlanningScenarios.last!.id : project.defaultPlanningScenarioID),
                displayOrder: n % 19, hierarchyLevel: n % 3 == 0 ? .mainDeliverable : .activityTask,
                title: "Activity \(n)", isDateless: n % 11 == 0,
                estimatedStartDate: date, estimatedEndDate: date.addingTimeInterval(-3600),
                isMilestone: n % 13 == 0, createdAt: date, updatedAt: date)
        }
        for n in activities.indices {
            activities[n].predecessorActivityIDs = [activities[n].id, activities[(n + 1) % count].id, activities[(n + projects.count) % count].id, UUID()]
            activities[n].linkedDeliverableIDs = [projects[0].deliverables[0].id, UUID()]
            if n >= projects.count { activities[n].parentActivityID = activities[n % projects.count].id }
        }
        // Raw parent cycle across valid project/scenario and hierarchy candidates.
        for n in 0..<4 {
            activities[n].projectID = projects[0].id
            activities[n].scenarioID = projects[0].defaultPlanningScenarioID
            activities[n].isMilestone = false
        }
        activities[0].hierarchyLevel = .activityTask
        activities[1].hierarchyLevel = .mainDeliverable
        activities[2].hierarchyLevel = .subtaskAction
        activities[0].parentActivityID = activities[1].id
        activities[1].parentActivityID = activities[2].id
        activities[2].parentActivityID = activities[0].id
        activities[3].hierarchyLevel = .archiveNote
        activities[3].parentActivityID = activities[0].id
        var orphan = activities[count - 1]
        orphan.id = UUID(); orphan.projectID = UUID()
        activities.append(orphan)
        return (projects, activities)
    }

    // Frozen pre-#57 implementation, used only as a behavioral/performance oracle.
    private func reference(_ activities: [ProjectActivity], projects: [Project]) -> [ProjectActivity] {
        let projectIDs = Set(projects.map(\.id))
        let filteredActivities = activities
            .filter { projectIDs.contains($0.projectID) }
        let activitiesByID = Dictionary(uniqueKeysWithValues: filteredActivities.map { ($0.id, $0) })
        let effectiveScenarioIDs = Dictionary(uniqueKeysWithValues: filteredActivities.map { activity in
            let scenarioID: UUID
            if let project = projects.first(where: { $0.id == activity.projectID }) {
                let validScenarioIDs = Set(project.orderedPlanningScenarios.map(\.id))
                scenarioID = validScenarioIDs.contains(activity.scenarioID)
                    ? activity.scenarioID
                    : project.defaultPlanningScenarioID
            } else {
                scenarioID = activity.scenarioID
            }
            return (activity.id, scenarioID)
        })

        return filteredActivities.map { activity in
                var normalized = activity
                normalized.scenarioID = effectiveScenarioIDs[activity.id] ?? activity.scenarioID
                if !activity.isDateless {
                    normalized.estimatedEndDate = max(activity.estimatedEndDate, activity.estimatedStartDate)
                }
                let projectActivityIDs = Set(
                    filteredActivities
                        .filter { $0.projectID == activity.projectID && effectiveScenarioIDs[$0.id] == normalized.scenarioID }
                        .map(\.id)
                )
                normalized.predecessorActivityIDs = activity.predecessorActivityIDs.filter {
                    $0 != activity.id && projectActivityIDs.contains($0)
                }
                if let parentActivityID = activity.parentActivityID {
                    let parentIsValid = {
                        guard parentActivityID != activity.id,
                              let parent = activitiesByID[parentActivityID],
                              parent.projectID == activity.projectID,
                              effectiveScenarioIDs[parentActivityID] == normalized.scenarioID,
                              parent.hierarchyLevel.sortRank < activity.hierarchyLevel.sortRank
                        else { return false }

                        var cursor: UUID? = parentActivityID
                        var visited = Set<UUID>()
                        while let cursorID = cursor, visited.insert(cursorID).inserted {
                            if cursorID == activity.id {
                                return false
                            }
                            cursor = activitiesByID[cursorID]?.parentActivityID
                        }
                        return true
                    }()

                    normalized.parentActivityID = parentIsValid ? parentActivityID : nil
                } else {
                    normalized.parentActivityID = nil
                }
                if let project = projects.first(where: { $0.id == activity.projectID }) {
                    let validDeliverableIDs = Set(project.deliverables.map(\.id))
                    normalized.linkedDeliverableIDs = activity.linkedDeliverableIDs.filter { validDeliverableIDs.contains($0) }
                } else {
                    normalized.linkedDeliverableIDs = []
                }
                return normalized
            }
    }

}
