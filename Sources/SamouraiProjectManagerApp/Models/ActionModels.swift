import Foundation

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
}

struct ProjectAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var priority: ActionPriority
    var dueDate: Date
    var flow: ActionFlow
    var projectID: UUID?
    var activityID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var isDone: Bool

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        priority: ActionPriority,
        dueDate: Date,
        flow: ActionFlow,
        projectID: UUID? = nil,
        activityID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.priority = priority
        self.dueDate = dueDate
        self.flow = flow
        self.projectID = projectID
        self.activityID = activityID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDone = isDone
    }
}

extension ProjectAction {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Action sans titre" : cleaned
    }
}
