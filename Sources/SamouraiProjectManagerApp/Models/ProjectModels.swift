import Foundation

enum ProjectPhase: String, Codable, CaseIterable, Identifiable {
    case cadrage
    case planning
    case delivery
    case stabilisation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cadrage:
            "Cadrage"
        case .planning:
            "Planning"
        case .delivery:
            "Delivery"
        case .stabilisation:
            "Stabilisation"
        }
    }
}

enum ProjectHealth: String, Codable, CaseIterable, Identifiable {
    case green
    case amber
    case red

    var id: String { rawValue }

    var label: String {
        switch self {
        case .green:
            "Sous contrôle"
        case .amber:
            "À surveiller"
        case .red:
            "Sous tension"
        }
    }

    var tintName: String {
        colorToken.rawValue
    }
}

enum DeliveryMode: String, Codable, CaseIterable, Identifiable {
    case waterfall
    case hybrid
    case agileFocused

    var id: String { rawValue }

    var label: String {
        switch self {
        case .waterfall:
            "Waterfall maîtrisé"
        case .hybrid:
            "Hybride Samourai"
        case .agileFocused:
            "Agile ciblé delivery"
        }
    }
}

struct ProjectPlanningScenario: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalizedScenarios(_ scenarios: [ProjectPlanningScenario], fallbackDate: Date = .now) -> [ProjectPlanningScenario] {
        var seen = Set<UUID>()
        let normalized = scenarios
            .filter { seen.insert($0.id).inserted }
            .map { scenario -> ProjectPlanningScenario in
                var updated = scenario
                let cleanedName = scenario.name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.name = cleanedName.isEmpty ? "Scénario" : cleanedName
                return updated
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.createdAt < rhs.createdAt
            }

        if normalized.isEmpty {
            return [
                ProjectPlanningScenario(
                    name: "Scénario 1",
                    createdAt: fallbackDate,
                    updatedAt: fallbackDate
                )
            ]
        }

        return normalized
    }
}

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var summary: String
    var sponsor: String
    var manager: String
    var phase: ProjectPhase
    var health: ProjectHealth
    var deliveryMode: DeliveryMode
    var startDate: Date
    var targetDate: Date
    var createdAt: Date
    var updatedAt: Date
    var risks: [Risk]
    var deliverables: [Deliverable]
    var scopeDefinition: ProjectScopeDefinition?
    var scopeBaselines: [ScopeBaseline]
    var scopeChangeRequests: [ScopeChangeRequest]
    var planningScenarios: [ProjectPlanningScenario]
    var planningBaselines: [PlanningBaseline]
    var testingPhases: [ProjectTestingPhase]

    init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        sponsor: String,
        manager: String,
        phase: ProjectPhase,
        health: ProjectHealth,
        deliveryMode: DeliveryMode,
        startDate: Date,
        targetDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        risks: [Risk] = [],
        deliverables: [Deliverable] = [],
        scopeDefinition: ProjectScopeDefinition? = nil,
        scopeBaselines: [ScopeBaseline] = [],
        scopeChangeRequests: [ScopeChangeRequest] = [],
        planningScenarios: [ProjectPlanningScenario] = [],
        planningBaselines: [PlanningBaseline] = [],
        testingPhases: [ProjectTestingPhase] = ProjectTestingPhase.defaultPhases
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.sponsor = sponsor
        self.manager = manager
        self.phase = phase
        self.health = health
        self.deliveryMode = deliveryMode
        self.startDate = startDate
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.risks = risks
        self.deliverables = deliverables
        self.scopeDefinition = scopeDefinition
        self.scopeBaselines = scopeBaselines.sorted { $0.createdAt < $1.createdAt }
        self.scopeChangeRequests = scopeChangeRequests.sorted { $0.createdAt < $1.createdAt }
        self.planningScenarios = ProjectPlanningScenario.normalizedScenarios(planningScenarios, fallbackDate: createdAt)
        self.planningBaselines = planningBaselines.sorted { $0.createdAt < $1.createdAt }
        self.testingPhases = ProjectTestingPhase.normalizedPhases(testingPhases)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, sponsor, manager, phase, health, deliveryMode
        case startDate, targetDate, createdAt, updatedAt
        case risks, deliverables, scopeDefinition, scopeBaselines
        case scopeChangeRequests, planningScenarios, planningBaselines, testingPhases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        sponsor = try container.decode(String.self, forKey: .sponsor)
        manager = try container.decode(String.self, forKey: .manager)
        phase = try container.decode(ProjectPhase.self, forKey: .phase)
        health = try container.decode(ProjectHealth.self, forKey: .health)
        deliveryMode = try container.decode(DeliveryMode.self, forKey: .deliveryMode)
        startDate = try container.decode(Date.self, forKey: .startDate)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        risks = try container.decode([Risk].self, forKey: .risks)
        deliverables = try container.decode([Deliverable].self, forKey: .deliverables)
        scopeDefinition = try container.decodeIfPresent(ProjectScopeDefinition.self, forKey: .scopeDefinition)
        scopeBaselines = (try container.decodeIfPresent([ScopeBaseline].self, forKey: .scopeBaselines) ?? [])
            .sorted { $0.createdAt < $1.createdAt }
        scopeChangeRequests = (try container.decodeIfPresent([ScopeChangeRequest].self, forKey: .scopeChangeRequests) ?? [])
            .sorted { $0.createdAt < $1.createdAt }
        planningScenarios = ProjectPlanningScenario.normalizedScenarios(
            try container.decodeIfPresent([ProjectPlanningScenario].self, forKey: .planningScenarios) ?? [],
            fallbackDate: createdAt
        )
        planningBaselines = (try container.decodeIfPresent([PlanningBaseline].self, forKey: .planningBaselines) ?? [])
            .sorted { $0.createdAt < $1.createdAt }
        testingPhases = ProjectTestingPhase.normalizedPhases(
            try container.decodeIfPresent([ProjectTestingPhase].self, forKey: .testingPhases) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(summary, forKey: .summary)
        try container.encode(sponsor, forKey: .sponsor)
        try container.encode(manager, forKey: .manager)
        try container.encode(phase, forKey: .phase)
        try container.encode(health, forKey: .health)
        try container.encode(deliveryMode, forKey: .deliveryMode)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(targetDate, forKey: .targetDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(risks, forKey: .risks)
        try container.encode(deliverables, forKey: .deliverables)
        try container.encodeIfPresent(scopeDefinition, forKey: .scopeDefinition)
        try container.encode(scopeBaselines, forKey: .scopeBaselines)
        try container.encode(scopeChangeRequests, forKey: .scopeChangeRequests)
        try container.encode(planningScenarios, forKey: .planningScenarios)
        try container.encode(planningBaselines, forKey: .planningBaselines)
        try container.encode(testingPhases, forKey: .testingPhases)
    }
}

extension Project {
    var sortedRisks: [Risk] {
        risks.sorted {
            if $0.severity.sortWeight == $1.severity.sortWeight {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.severity.sortWeight > $1.severity.sortWeight
        }
    }

    var sortedDeliverables: [Deliverable] {
        deliverables.sorted {
            if $0.dueDate == $1.dueDate {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.dueDate < $1.dueDate
        }
    }

    var completionRatio: Double {
        guard deliverables.isEmpty == false else { return 0 }
        let doneCount = deliverables.filter(\.isDone).count
        return Double(doneCount) / Double(deliverables.count)
    }

    var criticalRiskCount: Int {
        risks.filter { $0.severity == .critical }.count
    }

    var orderedTestingPhases: [ProjectTestingPhase] {
        ProjectTestingPhase.normalizedPhases(testingPhases)
    }

    var orderedPlanningScenarios: [ProjectPlanningScenario] {
        ProjectPlanningScenario.normalizedScenarios(planningScenarios, fallbackDate: createdAt)
    }

    var defaultPlanningScenarioID: UUID {
        orderedPlanningScenarios.first?.id ?? UUID()
    }

    var testingAverageProgressPercent: Int {
        let phases = orderedTestingPhases
        guard phases.isEmpty == false else { return 0 }
        let total = phases.reduce(0) { $0 + $1.progressPercent }
        return Int((Double(total) / Double(phases.count)).rounded())
    }

    var blockedTestingPhaseCount: Int {
        orderedTestingPhases.filter(\.isBlocked).count
    }

    var testingRAGStatus: ProjectTestingRAGStatus {
        let phases = orderedTestingPhases
        let delayedOrBlockedCount = phases.filter { $0.isBlocked || $0.isDelayed }.count
        let uatBlocked = phases.first(where: { $0.kind == .uat })?.isBlocked ?? false

        if uatBlocked || delayedOrBlockedCount >= 2 {
            return .red
        }

        if delayedOrBlockedCount >= 1 {
            return .amber
        }

        return .green
    }

    var isUATCompletedForGoNoGo: Bool {
        guard let uat = orderedTestingPhases.first(where: { $0.kind == .uat }) else { return false }
        return uat.progressPercent >= 100 || uat.status == .completed
    }
}
