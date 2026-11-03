import Foundation

private struct ActivityScope: Hashable {
    let projectID: UUID
    let scenarioID: UUID
}

/// Normalizes a batch using indexes built once, preserving input and link order.
enum ActivityNormalizer {
    static func normalize(_ activities: [ProjectActivity], projects: [Project]) -> [ProjectActivity] {
        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let projectIDs = Set(projectsByID.keys)
        let scenariosByProject = projectsByID.mapValues { Set($0.orderedPlanningScenarios.map(\.id)) }
        let defaultScenarioIDs = projectsByID.mapValues(\.defaultPlanningScenarioID)
        let deliverablesByProject = projectsByID.mapValues { Set($0.deliverables.map(\.id)) }
        let filteredActivities = activities
            .filter { projectIDs.contains($0.projectID) }
        let activitiesByID = Dictionary(uniqueKeysWithValues: filteredActivities.map { ($0.id, $0) })
        let effectiveScenarioIDs = Dictionary(uniqueKeysWithValues: filteredActivities.map { activity in
            let scenarioID: UUID
            if let project = projectsByID[activity.projectID] {
                let validScenarioIDs = scenariosByProject[project.id] ?? []
                scenarioID = validScenarioIDs.contains(activity.scenarioID)
                    ? activity.scenarioID
                    : defaultScenarioIDs[project.id]!
            } else {
                scenarioID = activity.scenarioID
            }
            return (activity.id, scenarioID)
        })

        var idsByScope: [ActivityScope: Set<UUID>] = [:]
        for activity in filteredActivities {
            let scope = ActivityScope(projectID: activity.projectID, scenarioID: effectiveScenarioIDs[activity.id]!)
            idsByScope[scope, default: []].insert(activity.id)
        }
        let cycleMembers = parentCycleMembers(activitiesByID)
        return filteredActivities.map { activity in
            var normalized = activity
            normalized.scenarioID = effectiveScenarioIDs[activity.id] ?? activity.scenarioID
            if !activity.isDateless {
                normalized.estimatedEndDate = max(activity.estimatedEndDate, activity.estimatedStartDate)
            }
            let projectActivityIDs = idsByScope[ActivityScope(projectID: activity.projectID, scenarioID: normalized.scenarioID)] ?? []
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

                    // Only cycle members can reach themselves through raw parent links.
                    if cycleMembers.contains(activity.id) { return false }
                    return true
                }()

                normalized.parentActivityID = parentIsValid ? parentActivityID : nil
            } else {
                normalized.parentActivityID = nil
            }
            if let project = projectsByID[activity.projectID] {
                let validDeliverableIDs = deliverablesByProject[project.id] ?? []
                normalized.linkedDeliverableIDs = activity.linkedDeliverableIDs.filter { validDeliverableIDs.contains($0) }
            } else {
                normalized.linkedDeliverableIDs = []
            }
            return normalized
        }
    }

    private static func parentCycleMembers(_ activities: [UUID: ProjectActivity]) -> Set<UUID> {
        var visited = Set<UUID>()
        var cyclic = Set<UUID>()
        for id in activities.keys where !visited.contains(id) {
            var path: [UUID] = []
            var positions: [UUID: Int] = [:]
            var cursor: UUID? = id
            while let current = cursor, activities[current] != nil, !visited.contains(current) {
                if let start = positions[current] {
                    cyclic.formUnion(path[start...])
                    break
                }
                positions[current] = path.count
                path.append(current)
                cursor = activities[current]?.parentActivityID
            }
            visited.formUnion(path)
        }
        return cyclic
    }
}

/// One ordered child index per rendered tree, shared by every expanded row.
struct ActivityTreeIndex {
    let roots: [ProjectActivity]
    let childrenByParent: [UUID: [ProjectActivity]]

    init(_ activities: [ProjectActivity], milestonesAsRoots: Bool = false) {
        roots = activities.filter {
            milestonesAsRoots ? ($0.parentActivityID == nil || $0.isMilestone) : ($0.parentActivityID == nil && !$0.isMilestone)
        }.sorted(by: ProjectActivity.planningDisplayOrderPrecedes)
        let groups = Dictionary(grouping: activities.filter { $0.parentActivityID != nil && !$0.isMilestone }) { $0.parentActivityID! }
        childrenByParent = groups.mapValues { $0.sorted(by: ProjectActivity.planningDisplayOrderPrecedes) }
    }

    func children(of id: UUID) -> [ProjectActivity] { childrenByParent[id] ?? [] }
}
