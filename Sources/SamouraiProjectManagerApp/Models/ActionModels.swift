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
    var flow: ActionFlow
    var projectID: UUID?
    var activityID: UUID?
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
        flow: ActionFlow,
        projectID: UUID? = nil,
        activityID: UUID? = nil,
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
        self.flow = flow
        self.projectID = projectID
        self.activityID = activityID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDone = isDone
        self.history = history
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
