import Foundation

struct ProjectScopeDefinition: Codable, Hashable {
    var inScopeItems: [String]
    var outOfScopeItems: [String]
    var linkedAnnexProjectIDs: [UUID]
    var updatedAt: Date

    init(
        inScopeItems: [String] = [],
        outOfScopeItems: [String] = [],
        linkedAnnexProjectIDs: [UUID] = [],
        updatedAt: Date = .now
    ) {
        self.inScopeItems = inScopeItems
        self.outOfScopeItems = outOfScopeItems
        self.linkedAnnexProjectIDs = linkedAnnexProjectIDs
        self.updatedAt = updatedAt
    }
}

struct ScopeBaseline: Identifiable, Codable, Hashable {
    var id: UUID
    var milestoneLabel: String
    var validatedBy: String
    var scopeSnapshot: ProjectScopeDefinition
    var deliverableSnapshots: [Deliverable]
    var associatedChangeRequestIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        milestoneLabel: String,
        validatedBy: String,
        scopeSnapshot: ProjectScopeDefinition,
        deliverableSnapshots: [Deliverable],
        associatedChangeRequestIDs: [UUID] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.milestoneLabel = milestoneLabel
        self.validatedBy = validatedBy
        self.scopeSnapshot = scopeSnapshot
        self.deliverableSnapshots = deliverableSnapshots
        self.associatedChangeRequestIDs = associatedChangeRequestIDs
        self.createdAt = createdAt
    }
}

enum ScopeChangeRequestStatus: String, Codable, CaseIterable, Identifiable {
    case proposed
    case reviewed
    case approved
    case rejected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .proposed:
            "Proposed"
        case .reviewed:
            "Reviewed"
        case .approved:
            "Approved"
        case .rejected:
            "Rejected"
        }
    }
}

struct ScopeChangeRequestHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var status: ScopeChangeRequestStatus
    var actor: String
    var note: String
    var changedAt: Date

    init(
        id: UUID = UUID(),
        status: ScopeChangeRequestStatus,
        actor: String,
        note: String = "",
        changedAt: Date = .now
    ) {
        self.id = id
        self.status = status
        self.actor = actor
        self.note = note
        self.changedAt = changedAt
    }
}

struct ScopeChangeRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var description: String
    var impactPlanning: String
    var impactResources: String
    var impactRisks: String
    var status: ScopeChangeRequestStatus
    var requestedBy: String
    var associatedBaselineID: UUID?
    var history: [ScopeChangeRequestHistoryEntry]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        description: String,
        impactPlanning: String,
        impactResources: String,
        impactRisks: String,
        status: ScopeChangeRequestStatus = .proposed,
        requestedBy: String,
        associatedBaselineID: UUID? = nil,
        history: [ScopeChangeRequestHistoryEntry] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.description = description
        self.impactPlanning = impactPlanning
        self.impactResources = impactResources
        self.impactRisks = impactRisks
        self.status = status
        self.requestedBy = requestedBy
        self.associatedBaselineID = associatedBaselineID
        self.history = history
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
