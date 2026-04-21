import Foundation

enum ActivityHierarchyLevel: String, Codable, CaseIterable, Identifiable {
    case governancePortfolio
    case program
    case strategicProject
    case criticalPhaseMilestone
    case mainDeliverable
    case activityTask
    case subtaskAction
    case archiveNote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .governancePortfolio:
            "Gouvernance / Portefeuille"
        case .program:
            "Programme"
        case .strategicProject:
            "Projet Stratégique"
        case .criticalPhaseMilestone:
            "Phase / Jalon Critique"
        case .mainDeliverable:
            "Livrable Principal"
        case .activityTask:
            "Activité / Tâche"
        case .subtaskAction:
            "Sous-tâche / Action"
        case .archiveNote:
            "Archive / Note"
        }
    }

    var sortRank: Int {
        switch self {
        case .governancePortfolio: return 1
        case .program: return 2
        case .strategicProject: return 3
        case .criticalPhaseMilestone: return 4
        case .mainDeliverable: return 5
        case .activityTask: return 6
        case .subtaskAction: return 7
        case .archiveNote: return 8
        }
    }
}

struct ProjectActivity: Identifiable, Codable, Hashable {
    var id: UUID
    var projectID: UUID
    var scenarioID: UUID
    var parentActivityID: UUID?
    var hierarchyLevel: ActivityHierarchyLevel
    var title: String
    var estimatedStartDate: Date
    var estimatedEndDate: Date
    var actualEndDate: Date?
    var predecessorActivityIDs: [UUID]
    var isMilestone: Bool
    var linkedDeliverableIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        scenarioID: UUID,
        parentActivityID: UUID? = nil,
        hierarchyLevel: ActivityHierarchyLevel = .activityTask,
        title: String,
        estimatedStartDate: Date,
        estimatedEndDate: Date,
        actualEndDate: Date? = nil,
        predecessorActivityIDs: [UUID] = [],
        isMilestone: Bool = false,
        linkedDeliverableIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.scenarioID = scenarioID
        self.parentActivityID = parentActivityID
        self.hierarchyLevel = hierarchyLevel
        self.title = title
        self.estimatedStartDate = estimatedStartDate
        self.estimatedEndDate = estimatedEndDate
        self.actualEndDate = actualEndDate
        self.predecessorActivityIDs = predecessorActivityIDs.removingDuplicateValues()
        self.isMilestone = isMilestone
        self.linkedDeliverableIDs = linkedDeliverableIDs.removingDuplicateValues()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectID, scenarioID, parentActivityID, hierarchyLevel, title
        case estimatedStartDate, estimatedEndDate, actualEndDate
        case predecessorActivityIDs, isMilestone, linkedDeliverableIDs
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        scenarioID = try container.decodeIfPresent(UUID.self, forKey: .scenarioID) ?? projectID
        parentActivityID = try container.decodeIfPresent(UUID.self, forKey: .parentActivityID)
        hierarchyLevel = try container.decodeIfPresent(ActivityHierarchyLevel.self, forKey: .hierarchyLevel) ?? .activityTask
        title = try container.decode(String.self, forKey: .title)
        estimatedStartDate = try container.decode(Date.self, forKey: .estimatedStartDate)
        estimatedEndDate = try container.decode(Date.self, forKey: .estimatedEndDate)
        actualEndDate = try container.decodeIfPresent(Date.self, forKey: .actualEndDate)
        predecessorActivityIDs = (try container.decodeIfPresent([UUID].self, forKey: .predecessorActivityIDs) ?? []).removingDuplicateValues()
        isMilestone = try container.decodeIfPresent(Bool.self, forKey: .isMilestone) ?? false
        linkedDeliverableIDs = (try container.decodeIfPresent([UUID].self, forKey: .linkedDeliverableIDs) ?? []).removingDuplicateValues()
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(scenarioID, forKey: .scenarioID)
        try container.encodeIfPresent(parentActivityID, forKey: .parentActivityID)
        try container.encode(hierarchyLevel, forKey: .hierarchyLevel)
        try container.encode(title, forKey: .title)
        try container.encode(estimatedStartDate, forKey: .estimatedStartDate)
        try container.encode(estimatedEndDate, forKey: .estimatedEndDate)
        try container.encodeIfPresent(actualEndDate, forKey: .actualEndDate)
        try container.encode(predecessorActivityIDs, forKey: .predecessorActivityIDs)
        try container.encode(isMilestone, forKey: .isMilestone)
        try container.encode(linkedDeliverableIDs, forKey: .linkedDeliverableIDs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

extension ProjectActivity {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Activité sans titre" : cleaned
    }

    var isCompleted: Bool {
        actualEndDate != nil
    }

    var estimatedDurationDays: Int {
        let days = Calendar.current.dateComponents([.day], from: estimatedStartDate, to: estimatedEndDate).day ?? 0
        return max(days, 0)
    }
}

struct PlanningBaselineActivitySnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var hierarchyLevel: ActivityHierarchyLevel
    var estimatedStartDate: Date
    var estimatedEndDate: Date
    var predecessorActivityIDs: [UUID]
    var isMilestone: Bool

    init(from activity: ProjectActivity) {
        id = activity.id
        title = activity.title
        hierarchyLevel = activity.hierarchyLevel
        estimatedStartDate = activity.estimatedStartDate
        estimatedEndDate = activity.estimatedEndDate
        predecessorActivityIDs = activity.predecessorActivityIDs
        isMilestone = activity.isMilestone
    }
}

struct PlanningBaseline: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var validatedBy: String
    var scenarioID: UUID?
    var activitySnapshots: [PlanningBaselineActivitySnapshot]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        validatedBy: String,
        scenarioID: UUID? = nil,
        activitySnapshots: [PlanningBaselineActivitySnapshot],
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.validatedBy = validatedBy
        self.scenarioID = scenarioID
        self.activitySnapshots = activitySnapshots
        self.createdAt = createdAt
    }
}

struct PlanningActivityVariance: Identifiable, Hashable {
    let activityID: UUID
    let title: String
    let plannedEndDate: Date
    let currentEndDate: Date
    let varianceDays: Int
    let isMilestone: Bool

    var id: UUID { activityID }
}

struct ProjectPlanningVarianceReport: Hashable {
    let baselineLabel: String
    let activityVariances: [PlanningActivityVariance]

    var delayedCount: Int {
        activityVariances.filter { $0.varianceDays > 0 }.count
    }

    var acceleratedCount: Int {
        activityVariances.filter { $0.varianceDays < 0 }.count
    }
}
