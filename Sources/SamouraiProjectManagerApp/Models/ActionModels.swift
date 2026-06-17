import Foundation
import SwiftUI

enum ActionStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case inProgress
    case done
    case cancelled
    case onHold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo:       "À faire"
        case .inProgress: "En cours"
        case .done:       "Terminé"
        case .cancelled:  "Annulé"
        case .onHold:     "En attente"
        }
    }
}

enum ActionFlow: String, Codable, CaseIterable, Identifiable {
    case manuel
    case automatique

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manuel:
            "Manuel"
        case .automatique:
            "Automatique"
        }
    }

    var systemImage: String {
        switch self {
        case .manuel:
            "hand.point.up.left.fill"
        case .automatique:
            "bolt.fill"
        }
    }
}

enum ActionPriority: String, Codable, CaseIterable, Identifiable {
    case trivial
    case minor
    case major
    case critical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trivial:
            "Trivial"
        case .minor:
            "Mineur"
        case .major:
            "Majeur"
        case .critical:
            "Critique"
        }
    }

    var sortWeight: Int {
        switch self {
        case .trivial:
            1
        case .minor:
            2
        case .major:
            3
        case .critical:
            4
        }
    }

    var tintName: String {
        colorToken.rawValue
    }

    var severityLevel: Int {
        sortWeight
    }

    init?(severityLevel: Int) {
        switch severityLevel {
        case 1: self = .trivial
        case 2: self = .minor
        case 3: self = .major
        case 4: self = .critical
        default: return nil
        }
    }

    var severityColor: Color {
        switch self {
        case .trivial:  Color(.sRGB, red: 136/255, green: 136/255, blue: 136/255, opacity: 1)
        case .minor:    Color(.sRGB, red: 0/255,   green: 175/255, blue: 95/255,  opacity: 1)
        case .major:    Color(.sRGB, red: 245/255, green: 166/255, blue: 35/255,  opacity: 1)
        case .critical: Color(.sRGB, red: 232/255, green: 65/255,  blue: 65/255,  opacity: 1)
        }
    }
}

enum ActionHistoryEntryKind: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic:
            "Modification automatique"
        case .manual:
            "Commentaire"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic:
            "gearshape"
        case .manual:
            "text.bubble"
        }
    }
}

struct ActionHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: ActionHistoryEntryKind
    var date: Date
    var text: String

    init(
        id: UUID = UUID(),
        kind: ActionHistoryEntryKind,
        date: Date = .now,
        text: String
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.text = text
    }
}

struct ProjectAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var priority: ActionPriority
    var status: ActionStatus
    var dueDate: Date
    var expectedDate: Date?
    var flow: ActionFlow
    var projectID: UUID?
    var activityID: UUID?
    var assignedResourceID: UUID?
    var expectedDeliverableIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var isDone: Bool
    var history: [ActionHistoryEntry]?

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        priority: ActionPriority,
        status: ActionStatus = .todo,
        dueDate: Date,
        expectedDate: Date? = nil,
        flow: ActionFlow,
        projectID: UUID? = nil,
        activityID: UUID? = nil,
        assignedResourceID: UUID? = nil,
        expectedDeliverableIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDone: Bool = false,
        history: [ActionHistoryEntry]? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.expectedDate = expectedDate
        self.flow = flow
        self.projectID = projectID
        self.activityID = activityID
        self.assignedResourceID = assignedResourceID
        self.expectedDeliverableIDs = expectedDeliverableIDs.removingDuplicateValues()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDone = isDone
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, priority, status, dueDate, expectedDate, flow
        case projectID, activityID, assignedResourceID, expectedDeliverableIDs
        case createdAt, updatedAt, isDone, history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        priority = try container.decode(ActionPriority.self, forKey: .priority)
        status = try container.decode(ActionStatus.self, forKey: .status)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        expectedDate = try container.decodeIfPresent(Date.self, forKey: .expectedDate)
        flow = try container.decode(ActionFlow.self, forKey: .flow)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        activityID = try container.decodeIfPresent(UUID.self, forKey: .activityID)
        assignedResourceID = try container.decodeIfPresent(UUID.self, forKey: .assignedResourceID)
        expectedDeliverableIDs = (try container.decodeIfPresent([UUID].self, forKey: .expectedDeliverableIDs) ?? []).removingDuplicateValues()
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        history = try container.decodeIfPresent([ActionHistoryEntry].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(expectedDate, forKey: .expectedDate)
        try container.encode(flow, forKey: .flow)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encodeIfPresent(activityID, forKey: .activityID)
        try container.encodeIfPresent(assignedResourceID, forKey: .assignedResourceID)
        try container.encode(expectedDeliverableIDs, forKey: .expectedDeliverableIDs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isDone, forKey: .isDone)
        try container.encodeIfPresent(history, forKey: .history)
    }
}

extension ProjectAction {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Action sans titre" : cleaned
    }

    var historyEntries: [ActionHistoryEntry] {
        history ?? []
    }

    var historyEntriesChronological: [ActionHistoryEntry] {
        historyEntries.sorted { $0.date < $1.date }
    }
}
