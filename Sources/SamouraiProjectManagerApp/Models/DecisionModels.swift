import Foundation

enum DecisionStatus: String, Codable, CaseIterable, Identifiable {
    case proposedUnderReview
    case validated
    case abandoned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .proposedUnderReview:
            "Proposée / En Cours d'Étude"
        case .validated:
            "Validée"
        case .abandoned:
            "Abandonnée"
        }
    }

    var shortLabel: String {
        switch self {
        case .proposedUnderReview:
            "Proposée"
        case .validated:
            "Validée"
        case .abandoned:
            "Abandonnée"
        }
    }

    var tintName: String {
        colorToken.rawValue
    }
}

struct DecisionHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var revision: Int
    var summary: String
    var status: DecisionStatus
    var snapshotTitle: String
    var snapshotDetails: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        revision: Int,
        summary: String,
        status: DecisionStatus,
        snapshotTitle: String,
        snapshotDetails: String,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.revision = max(revision, 1)
        self.summary = summary
        self.status = status
        self.snapshotTitle = snapshotTitle
        self.snapshotDetails = snapshotDetails
        self.recordedAt = recordedAt
    }
}

struct DecisionComment: Identifiable, Codable, Hashable {
    var id: UUID
    var author: String
    var body: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        author: String,
        body: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

struct ProjectDecision: Identifiable, Codable, Hashable {
    var id: UUID
    var sequenceNumber: Int
    var title: String
    var details: String
    var status: DecisionStatus
    var projectID: UUID?
    var meetingIDs: [UUID]
    var eventIDs: [UUID]
    var impactedResourceIDs: [UUID]
    var history: [DecisionHistoryEntry]
    var comments: [DecisionComment]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        title: String,
        details: String,
        status: DecisionStatus = .proposedUnderReview,
        projectID: UUID? = nil,
        meetingIDs: [UUID] = [],
        eventIDs: [UUID] = [],
        impactedResourceIDs: [UUID] = [],
        history: [DecisionHistoryEntry] = [],
        comments: [DecisionComment] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sequenceNumber = max(sequenceNumber, 1)
        self.title = title
        self.details = details
        self.status = status
        self.projectID = projectID
        self.meetingIDs = meetingIDs.removingDuplicateValues()
        self.eventIDs = eventIDs.removingDuplicateValues()
        self.impactedResourceIDs = impactedResourceIDs.removingDuplicateValues()
        self.history = history.sorted { $0.recordedAt < $1.recordedAt }
        self.comments = comments.sorted { $0.createdAt < $1.createdAt }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectDecision {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Décision sans titre" : cleaned
    }
}
