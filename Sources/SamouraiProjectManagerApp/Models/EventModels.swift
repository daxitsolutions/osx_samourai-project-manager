import Foundation

enum EventPriority: String, Codable, CaseIterable, Identifiable {
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

struct ProjectEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var source: String
    var priority: EventPriority
    var happenedAt: Date
    var projectID: UUID?
    var resourceIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        source: String = "",
        priority: EventPriority,
        happenedAt: Date = .now,
        projectID: UUID? = nil,
        resourceIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.source = source
        self.priority = priority
        self.happenedAt = happenedAt
        self.projectID = projectID
        self.resourceIDs = resourceIDs.removingDuplicateValues()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectEvent {
    var displayTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Événement sans titre" : value
    }

    var hasTextContent: Bool {
        details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasSource: Bool {
        source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
