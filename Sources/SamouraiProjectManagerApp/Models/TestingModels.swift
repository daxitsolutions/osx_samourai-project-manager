import Foundation

enum ProjectTestingPhaseKind: String, Codable, CaseIterable, Identifiable {
    case ut
    case st
    case ist
    case uat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ut:
            "Unit Tests (UT)"
        case .st:
            "System Tests (ST)"
        case .ist:
            "Integration Tests (IST)"
        case .uat:
            "User Acceptance Tests (UAT)"
        }
    }

    var shortLabel: String {
        rawValue.uppercased()
    }
}

enum ProjectTestingPhaseStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted
    case inProgress
    case completed
    case blocked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted:
            "Non démarré"
        case .inProgress:
            "En cours"
        case .completed:
            "Terminé"
        case .blocked:
            "Bloqué"
        }
    }
}

enum ProjectTestingRAGStatus: String, Codable, CaseIterable, Identifiable {
    case green
    case amber
    case red

    var id: String { rawValue }

    var label: String {
        switch self {
        case .green:
            "Vert"
        case .amber:
            "Ambre"
        case .red:
            "Rouge"
        }
    }

    var tintName: String {
        colorToken.rawValue
    }

    var symbol: String {
        switch self {
        case .green:
            "🟢"
        case .amber:
            "🟡"
        case .red:
            "🔴"
        }
    }
}

struct ProjectTestingPhase: Identifiable, Codable, Hashable {
    var kind: ProjectTestingPhaseKind
    var status: ProjectTestingPhaseStatus
    var progressPercent: Int
    var estimatedEndDate: Date?
    var actualEndDate: Date?
    var owner: String
    var notes: String
    var externalURL: String

    var id: String { kind.id }

    init(
        kind: ProjectTestingPhaseKind,
        status: ProjectTestingPhaseStatus = .notStarted,
        progressPercent: Int = 0,
        estimatedEndDate: Date? = nil,
        actualEndDate: Date? = nil,
        owner: String = "",
        notes: String = "",
        externalURL: String = ""
    ) {
        self.kind = kind
        self.status = status
        self.progressPercent = min(max(progressPercent, 0), 100)
        self.estimatedEndDate = estimatedEndDate
        self.actualEndDate = actualEndDate
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.externalURL = externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizeConsistency()
    }

    var isBlocked: Bool {
        status == .blocked
    }

    var isDelayed: Bool {
        guard isCompleted == false, let estimatedEndDate else { return false }
        return estimatedEndDate < Calendar.current.startOfDay(for: .now)
    }

    var isCompleted: Bool {
        status == .completed || progressPercent >= 100
    }

    static var defaultPhases: [ProjectTestingPhase] {
        ProjectTestingPhaseKind.allCases.map { ProjectTestingPhase(kind: $0) }
    }

    static func normalizedPhases(_ phases: [ProjectTestingPhase]) -> [ProjectTestingPhase] {
        let byKind = Dictionary(uniqueKeysWithValues: phases.map { ($0.kind, $0) })
        return ProjectTestingPhaseKind.allCases.map { kind in
            if var existing = byKind[kind] {
                existing.normalizeConsistency()
                return existing
            }
            return ProjectTestingPhase(kind: kind)
        }
    }

    private mutating func normalizeConsistency() {
        progressPercent = min(max(progressPercent, 0), 100)
        owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        externalURL = externalURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if status == .completed {
            progressPercent = 100
        } else if progressPercent >= 100, status != .blocked {
            status = .completed
            progressPercent = 100
        } else if progressPercent > 0, status == .notStarted {
            status = .inProgress
        }
    }
}
