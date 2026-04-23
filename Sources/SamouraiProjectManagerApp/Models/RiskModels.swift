import Foundation

enum RiskSeverity: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:
            "Faible"
        case .medium:
            "Moyen"
        case .high:
            "Élevé"
        case .critical:
            "Critique"
        }
    }

    var sortWeight: Int {
        switch self {
        case .low:
            1
        case .medium:
            2
        case .high:
            3
        case .critical:
            4
        }
    }
}

enum RiskStatus: String, Codable, CaseIterable, Identifiable {
    case toDo = "À faire"
    case inProgress = "En cours"
    case done = "Terminé"
    case cancelled = "Annulé"
    case transformedToIncident = "Transformé en Incidence"

    var id: String { rawValue }

    var label: String { rawValue }

    var hexColor: String {
        switch self {
        case .toDo:
            "#8A5CF5"
        case .inProgress:
            "#2C7BE5"
        case .done:
            "#00AF5F"
        case .cancelled:
            "#888888"
        case .transformedToIncident:
            "#F5A623"
        }
    }

    var sortWeight: Int {
        switch self {
        case .toDo:
            1
        case .inProgress:
            2
        case .done:
            3
        case .cancelled:
            4
        case .transformedToIncident:
            5
        }
    }

    static func from(rawString: String?) -> RiskStatus? {
        guard let trimmed = rawString?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else { return nil }
        return RiskStatus(rawValue: trimmed)
    }
}

enum RiskHistoryEntryKind: String, Codable, CaseIterable, Identifiable {
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

struct RiskHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: RiskHistoryEntryKind
    var date: Date
    var text: String

    init(
        id: UUID = UUID(),
        kind: RiskHistoryEntryKind,
        date: Date = .now,
        text: String
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.text = text
    }
}

struct Risk: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var mitigation: String
    var owner: String
    var severity: RiskSeverity
    var dueDate: Date?
    var createdAt: Date
    var externalID: String?
    var projectNames: String?
    var detectedBy: String?
    var assignedTo: String?
    var lastModifiedAt: Date?
    var riskType: String?
    var response: String?
    var riskTitle: String?
    var riskOrigin: String?
    var impactDescription: String?
    var counterMeasure: String?
    var followUpComment: String?
    var proximity: String?
    var probability: String?
    var impactScope: String?
    var impactBudget: String?
    var impactPlanning: String?
    var impactResources: String?
    var impactTransition: String?
    var impactSecurityIT: String?
    var escalationLevel: String?
    var riskStatus: String?
    var score0to10: Double?
    var history: [RiskHistoryEntry]?

    init(
        id: UUID = UUID(),
        title: String,
        mitigation: String,
        owner: String,
        severity: RiskSeverity,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        externalID: String? = nil,
        projectNames: String? = nil,
        detectedBy: String? = nil,
        assignedTo: String? = nil,
        lastModifiedAt: Date? = nil,
        riskType: String? = nil,
        response: String? = nil,
        riskTitle: String? = nil,
        riskOrigin: String? = nil,
        impactDescription: String? = nil,
        counterMeasure: String? = nil,
        followUpComment: String? = nil,
        proximity: String? = nil,
        probability: String? = nil,
        impactScope: String? = nil,
        impactBudget: String? = nil,
        impactPlanning: String? = nil,
        impactResources: String? = nil,
        impactTransition: String? = nil,
        impactSecurityIT: String? = nil,
        escalationLevel: String? = nil,
        riskStatus: String? = nil,
        score0to10: Double? = nil,
        history: [RiskHistoryEntry]? = nil
    ) {
        self.id = id
        self.title = title
        self.mitigation = mitigation
        self.owner = owner
        self.severity = severity
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.externalID = externalID
        self.projectNames = projectNames
        self.detectedBy = detectedBy
        self.assignedTo = assignedTo
        self.lastModifiedAt = lastModifiedAt
        self.riskType = riskType
        self.response = response
        self.riskTitle = riskTitle
        self.riskOrigin = riskOrigin
        self.impactDescription = impactDescription
        self.counterMeasure = counterMeasure
        self.followUpComment = followUpComment
        self.proximity = proximity
        self.probability = probability
        self.impactScope = impactScope
        self.impactBudget = impactBudget
        self.impactPlanning = impactPlanning
        self.impactResources = impactResources
        self.impactTransition = impactTransition
        self.impactSecurityIT = impactSecurityIT
        self.escalationLevel = escalationLevel
        self.riskStatus = riskStatus
        self.score0to10 = score0to10
        self.history = history
    }
}

extension Risk {
    var displayTitle: String {
        let value = riskTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? title : value
    }

    var displayOwner: String {
        let value = assignedTo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? owner : value
    }

    var displayMitigation: String {
        let value = counterMeasure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? mitigation : value
    }

    var displayStatus: String {
        let value = riskStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Non renseigné" : value
    }

    var historyEntries: [RiskHistoryEntry] {
        history ?? []
    }

    var historyEntriesChronological: [RiskHistoryEntry] {
        historyEntries.sorted { $0.date < $1.date }
    }
}
