import Foundation

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
        case id
        case name
        case summary
        case sponsor
        case manager
        case phase
        case health
        case deliveryMode
        case startDate
        case targetDate
        case createdAt
        case updatedAt
        case risks
        case deliverables
        case scopeDefinition
        case scopeBaselines
        case scopeChangeRequests
        case planningScenarios
        case planningBaselines
        case testingPhases
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

enum ReportingCadence: String, Codable, CaseIterable, Identifiable, Hashable {
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:
            "Hebdomadaire"
        case .monthly:
            "Mensuel"
        }
    }

    var periodHorizonDays: Int {
        switch self {
        case .weekly:
            7
        case .monthly:
            30
        }
    }
}

struct GovernanceReport: Codable, Hashable {
    struct ExecutiveSummary: Codable, Hashable {
        let ragStatus: ProjectHealth
        let progressPercent: Int
        let criticalRiskCount: Int
        let criticalRiskDeltaFromPreviousPeriod: Int
        let testsAveragePercent: Int
        let blockedTestingPhases: Int
        let testsRAGStatus: ProjectTestingRAGStatus
    }

    let cadence: ReportingCadence
    let scopeLabel: String
    let periodStart: Date
    let periodEndExclusive: Date
    let generatedAt: Date
    let executiveSummary: ExecutiveSummary
    let accomplishments: [String]
    let variancesAndChanges: [String]
    let nextSteps: [String]
}

extension GovernanceReport {
    var title: String {
        "Reporting \(cadence.label)"
    }

    var periodLabel: String {
        let endInclusive = Calendar.current.date(byAdding: .day, value: -1, to: periodEndExclusive) ?? periodStart
        return "\(periodStart.formatted(date: .abbreviated, time: .omitted)) → \(endInclusive.formatted(date: .abbreviated, time: .omitted))"
    }

    var markdownText: String {
        let delta = executiveSummary.criticalRiskDeltaFromPreviousPeriod
        let deltaLabel: String = {
            if delta == 0 { return "stable" }
            return delta > 0 ? "+\(delta)" : "\(delta)"
        }()

        let accomplishmentsText = accomplishments.isEmpty
            ? "- Aucun accomplissement détecté sur la période."
            : accomplishments.map { "- \($0)" }.joined(separator: "\n")

        let variancesText = variancesAndChanges.isEmpty
            ? "- Aucun écart significatif détecté."
            : variancesAndChanges.map { "- \($0)" }.joined(separator: "\n")

        let nextStepsText = nextSteps.isEmpty
            ? "- Aucune échéance majeure dans l'horizon considéré."
            : nextSteps.map { "- \($0)" }.joined(separator: "\n")

        return """
        # \(title)

        - Généré le: \(generatedAt.formatted(date: .abbreviated, time: .shortened))
        - Périmètre: \(scopeLabel)
        - Période: \(periodLabel)

        ## Synthèse Exécutive (RAG)
        - État global: \(executiveSummary.ragStatus.label)
        - Avancement global (Livrables + Activités): \(executiveSummary.progressPercent)%
        - Risques critiques: \(executiveSummary.criticalRiskCount) (évolution vs période précédente: \(deltaLabel))
        - Santé tests moyenne: \(executiveSummary.testsAveragePercent)% (\(executiveSummary.testsRAGStatus.symbol) \(executiveSummary.testsRAGStatus.label))
        - Phases de tests bloquées: \(executiveSummary.blockedTestingPhases)

        ## Accomplissements
        \(accomplishmentsText)

        ## Écarts & Changements
        \(variancesText)

        ## Prochaines Étapes
        \(nextStepsText)
        """
    }
}

struct GovernanceReportRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var generatedReport: GovernanceReport
    var scopedProjectIDs: [UUID]?
    var executiveSummaryPMNote: String
    var planningActionsPMNote: String
    var conclusionPMMessage: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        generatedReport: GovernanceReport,
        scopedProjectIDs: [UUID]? = nil,
        executiveSummaryPMNote: String = "",
        planningActionsPMNote: String = "",
        conclusionPMMessage: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.generatedReport = generatedReport
        self.scopedProjectIDs = scopedProjectIDs?.removingDuplicateValues()
        self.executiveSummaryPMNote = executiveSummaryPMNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.planningActionsPMNote = planningActionsPMNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.conclusionPMMessage = conclusionPMMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension GovernanceReportRecord {
    var title: String {
        generatedReport.title
    }

    var periodLabel: String {
        generatedReport.periodLabel
    }

    var projectsLabel: String {
        generatedReport.scopeLabel
    }

    var executiveHighlightsAuto: [String] {
        let summary = generatedReport.executiveSummary
        let delta = summary.criticalRiskDeltaFromPreviousPeriod
        let deltaLabel = delta == 0 ? "stable" : (delta > 0 ? "+\(delta)" : "\(delta)")
        return [
            "RAG global: \(summary.ragStatus.label).",
            "Avancement global (livrables + activités): \(summary.progressPercent)%.",
            "Risques critiques: \(summary.criticalRiskCount) (évolution \(deltaLabel) vs période précédente).",
            "Santé tests: \(summary.testsAveragePercent)% (\(summary.testsRAGStatus.symbol) \(summary.testsRAGStatus.label))."
        ]
    }

    var testsProgressAutoLines: [String] {
        let summary = generatedReport.executiveSummary
        return [
            "Statut agrégé: \(summary.testsRAGStatus.symbol) \(summary.testsRAGStatus.label).",
            "Taux moyen des 4 phases (UT/ST/IST/UAT): \(summary.testsAveragePercent)%.",
            "Nombre de phases bloquées: \(summary.blockedTestingPhases)."
        ]
    }

    var risksAndBlocksAutoLines: [String] {
        let candidate = generatedReport.variancesAndChanges
            .filter { value in
                let normalized = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return normalized.contains("risque")
                    || normalized.contains("bloqu")
                    || normalized.contains("retard")
                    || normalized.contains("uat")
                    || normalized.contains("ist")
            }
        return candidate.isEmpty ? ["Aucun signal critique supplémentaire détecté automatiquement."] : candidate
    }

    var nextPlanningAutoLines: [String] {
        generatedReport.nextSteps
    }

    var markdownOnePager: String {
        let autoDone = generatedReport.accomplishments.prefix(6)
        let autoRisks = risksAndBlocksAutoLines.prefix(6)
        let autoPlan = nextPlanningAutoLines.prefix(6)

        let doneText = autoDone.isEmpty
            ? "- Aucun accomplissement détecté automatiquement."
            : autoDone.map { "- \($0)" }.joined(separator: "\n")
        let risksText = autoRisks.isEmpty
            ? "- Aucun risque/blocage nouveau détecté."
            : autoRisks.map { "- \($0)" }.joined(separator: "\n")
        let planText = autoPlan.isEmpty
            ? "- Aucun élément majeur attendu sur l'horizon."
            : autoPlan.map { "- \($0)" }.joined(separator: "\n")
        let executiveText = executiveHighlightsAuto.prefix(4).map { "- \($0)" }.joined(separator: "\n")
        let executivePMText = executiveSummaryPMNote.isEmpty ? "_Aucun complément PM._" : executiveSummaryPMNote
        let planningPMText = planningActionsPMNote.isEmpty ? "_Aucune action PM complémentaire._" : planningActionsPMNote
        let conclusionText = conclusionPMMessage.isEmpty ? "_Aucun message complémentaire._" : conclusionPMMessage

        return """
        # \(title)

        ## 1) En-tête & Contexte
        - Période couverte: \(periodLabel)
        - Projets concernés: \(projectsLabel)

        ## 2) Résumé Exécutif
        \(executiveText)
        - Complément PM: \(executivePMText)

        ## 3) Accomplissements (Done)
        \(doneText)

        ## 4) Avancement des Tests
        \(testsProgressAutoLines.map { "- \($0)" }.joined(separator: "\n"))

        ## 5) Risques, Problèmes & Blocages
        \(risksText)

        ## 6) Planification Prochaine
        \(planText)
        - Actions PM spécifiques: \(planningPMText)

        ## 7) Conclusion & Actions Requises
        \(conclusionText)
        """
    }

    var plainTextOnePager: String {
        markdownOnePager
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "_", with: "")
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
        score0to10: Double? = nil
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
}

struct Deliverable: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var owner: String
    var dueDate: Date
    var isDone: Bool
    var phase: DeliverablePhase
    var parentDeliverableID: UUID?
    var isMilestone: Bool
    var acceptanceCriteria: [DeliverableAcceptanceCriterion]
    var integratedSourceProjectID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        owner: String,
        dueDate: Date,
        isDone: Bool = false,
        phase: DeliverablePhase = .delivery,
        parentDeliverableID: UUID? = nil,
        isMilestone: Bool = false,
        acceptanceCriteria: [DeliverableAcceptanceCriterion] = [],
        integratedSourceProjectID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.owner = owner
        self.dueDate = dueDate
        self.isDone = isDone
        self.phase = phase
        self.parentDeliverableID = parentDeliverableID
        self.isMilestone = isMilestone
        self.acceptanceCriteria = acceptanceCriteria
        self.integratedSourceProjectID = integratedSourceProjectID
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case details
        case owner
        case dueDate
        case isDone
        case phase
        case parentDeliverableID
        case isMilestone
        case acceptanceCriteria
        case integratedSourceProjectID
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        owner = try container.decode(String.self, forKey: .owner)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        phase = try container.decodeIfPresent(DeliverablePhase.self, forKey: .phase) ?? .delivery
        parentDeliverableID = try container.decodeIfPresent(UUID.self, forKey: .parentDeliverableID)
        isMilestone = try container.decodeIfPresent(Bool.self, forKey: .isMilestone) ?? false
        acceptanceCriteria = try container.decodeIfPresent([DeliverableAcceptanceCriterion].self, forKey: .acceptanceCriteria) ?? []
        integratedSourceProjectID = try container.decodeIfPresent(UUID.self, forKey: .integratedSourceProjectID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(owner, forKey: .owner)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(parentDeliverableID, forKey: .parentDeliverableID)
        try container.encode(isMilestone, forKey: .isMilestone)
        try container.encode(acceptanceCriteria, forKey: .acceptanceCriteria)
        try container.encodeIfPresent(integratedSourceProjectID, forKey: .integratedSourceProjectID)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct DeliverableAcceptanceCriterion: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var isValidated: Bool

    init(id: UUID = UUID(), text: String, isValidated: Bool = false) {
        self.id = id
        self.text = text
        self.isValidated = isValidated
    }
}

enum DeliverablePhase: String, Codable, CaseIterable, Identifiable {
    case cadrage
    case design
    case build
    case tests
    case deployment
    case transition
    case delivery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cadrage:
            "Cadrage"
        case .design:
            "Design"
        case .build:
            "Build"
        case .tests:
            "Tests"
        case .deployment:
            "Déploiement"
        case .transition:
            "Transition"
        case .delivery:
            "Delivery"
        }
    }
}

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

extension Deliverable {
    var isMainDeliverable: Bool {
        parentDeliverableID == nil
    }

    var validatedAcceptanceCount: Int {
        acceptanceCriteria.filter(\.isValidated).count
    }

    var acceptanceCompletionPercent: Int {
        guard acceptanceCriteria.isEmpty == false else { return 0 }
        return Int((Double(validatedAcceptanceCount) / Double(acceptanceCriteria.count) * 100).rounded())
    }

    var isAccepted: Bool {
        if acceptanceCriteria.isEmpty {
            return isDone
        }
        return validatedAcceptanceCount == acceptanceCriteria.count
    }
}

struct ScopeCoverageEntry: Identifiable, Hashable {
    let deliverableID: UUID
    let title: String
    let isMilestone: Bool
    let linkedActivityCount: Int

    var id: UUID { deliverableID }
    var isCovered: Bool { isMilestone || linkedActivityCount > 0 }
}

struct ScopeCoverageReport: Hashable {
    let entries: [ScopeCoverageEntry]

    var totalCount: Int { entries.count }
    var coveredCount: Int { entries.filter(\.isCovered).count }
    var coveragePercent: Int {
        guard totalCount > 0 else { return 100 }
        return Int((Double(coveredCount) / Double(totalCount) * 100).rounded())
    }
}

struct ScopeBaselineExecutionProgress: Hashable {
    let baselineLabel: String
    let acceptedCount: Int
    let totalCount: Int

    var progressPercent: Int {
        guard totalCount > 0 else { return 100 }
        return Int((Double(acceptedCount) / Double(totalCount) * 100).rounded())
    }
}

struct RiskEntry: Identifiable, Hashable {
    let projectID: UUID?
    let projectName: String
    let risk: Risk

    var id: UUID { risk.id }
}

struct DeliverableEntry: Identifiable, Hashable {
    let projectID: UUID
    let projectName: String
    let deliverable: Deliverable

    var id: UUID { deliverable.id }
}

struct Resource: Identifiable, Codable, Hashable {
    var id: UUID
    var fullName: String
    var jobTitle: String
    var department: String
    var nom: String?
    var parentDescription: String?
    var primaryResourceRole: String?
    var resourceRoles: String?
    var organizationalResource: String?
    var competence1: String?
    var resourceCalendar: String?
    var resourceStartDate: Date?
    var resourceFinishDate: Date?
    var responsableOperationnel: String?
    var responsableInterne: String?
    var localisation: String?
    var typeDeRessource: String?
    var journeesTempsPartiel: String?
    var email: String
    var phone: String
    var engagement: ResourceEngagement
    var status: ResourceStatus
    var allocationPercent: Int
    var assignedProjectIDs: [UUID]
    var favoriteProjectIDs: [UUID]
    var performanceEvaluations: [ResourcePerformanceEvaluation]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String,
        jobTitle: String,
        department: String,
        nom: String? = nil,
        parentDescription: String? = nil,
        primaryResourceRole: String? = nil,
        resourceRoles: String? = nil,
        organizationalResource: String? = nil,
        competence1: String? = nil,
        resourceCalendar: String? = nil,
        resourceStartDate: Date? = nil,
        resourceFinishDate: Date? = nil,
        responsableOperationnel: String? = nil,
        responsableInterne: String? = nil,
        localisation: String? = nil,
        typeDeRessource: String? = nil,
        journeesTempsPartiel: String? = nil,
        email: String,
        phone: String,
        engagement: ResourceEngagement,
        status: ResourceStatus,
        allocationPercent: Int,
        assignedProjectIDs: [UUID] = [],
        favoriteProjectIDs: [UUID] = [],
        performanceEvaluations: [ResourcePerformanceEvaluation] = [],
        notes: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.jobTitle = jobTitle
        self.department = department
        self.nom = nom
        self.parentDescription = parentDescription
        self.primaryResourceRole = primaryResourceRole
        self.resourceRoles = resourceRoles
        self.organizationalResource = organizationalResource
        self.competence1 = competence1
        self.resourceCalendar = resourceCalendar
        self.resourceStartDate = resourceStartDate
        self.resourceFinishDate = resourceFinishDate
        self.responsableOperationnel = responsableOperationnel
        self.responsableInterne = responsableInterne
        self.localisation = localisation
        self.typeDeRessource = typeDeRessource
        self.journeesTempsPartiel = journeesTempsPartiel
        self.email = email
        self.phone = phone
        self.engagement = engagement
        self.status = status
        self.allocationPercent = allocationPercent
        let normalizedAssignedProjectIDs = assignedProjectIDs.removingDuplicateValues()
        self.assignedProjectIDs = normalizedAssignedProjectIDs
        self.favoriteProjectIDs = favoriteProjectIDs
            .removingDuplicateValues()
            .filter { normalizedAssignedProjectIDs.contains($0) }
        self.performanceEvaluations = performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case jobTitle
        case department
        case nom
        case parentDescription
        case primaryResourceRole
        case resourceRoles
        case organizationalResource
        case competence1
        case resourceCalendar
        case resourceStartDate
        case resourceFinishDate
        case responsableOperationnel
        case responsableInterne
        case localisation
        case typeDeRessource
        case journeesTempsPartiel
        case email
        case phone
        case engagement
        case status
        case allocationPercent
        case assignedProjectIDs
        case favoriteProjectIDs
        case assignedProjectID
        case performanceEvaluations
        case notes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        jobTitle = try container.decode(String.self, forKey: .jobTitle)
        department = try container.decode(String.self, forKey: .department)
        nom = try container.decodeIfPresent(String.self, forKey: .nom)
        parentDescription = try container.decodeIfPresent(String.self, forKey: .parentDescription)
        primaryResourceRole = try container.decodeIfPresent(String.self, forKey: .primaryResourceRole)
        resourceRoles = try container.decodeIfPresent(String.self, forKey: .resourceRoles)
        organizationalResource = try container.decodeIfPresent(String.self, forKey: .organizationalResource)
        competence1 = try container.decodeIfPresent(String.self, forKey: .competence1)
        resourceCalendar = try container.decodeIfPresent(String.self, forKey: .resourceCalendar)
        resourceStartDate = try container.decodeIfPresent(Date.self, forKey: .resourceStartDate)
        resourceFinishDate = try container.decodeIfPresent(Date.self, forKey: .resourceFinishDate)
        responsableOperationnel = try container.decodeIfPresent(String.self, forKey: .responsableOperationnel)
        responsableInterne = try container.decodeIfPresent(String.self, forKey: .responsableInterne)
        localisation = try container.decodeIfPresent(String.self, forKey: .localisation)
        typeDeRessource = try container.decodeIfPresent(String.self, forKey: .typeDeRessource)
        journeesTempsPartiel = try container.decodeIfPresent(String.self, forKey: .journeesTempsPartiel)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        engagement = try container.decode(ResourceEngagement.self, forKey: .engagement)
        status = try container.decode(ResourceStatus.self, forKey: .status)
        allocationPercent = try container.decode(Int.self, forKey: .allocationPercent)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        let decodedAssignedProjectIDs: [UUID]
        if let multiAssignments = try container.decodeIfPresent([UUID].self, forKey: .assignedProjectIDs) {
            decodedAssignedProjectIDs = multiAssignments.removingDuplicateValues()
        } else if let legacyAssignment = try container.decodeIfPresent(UUID.self, forKey: .assignedProjectID) {
            decodedAssignedProjectIDs = [legacyAssignment]
        } else {
            decodedAssignedProjectIDs = []
        }
        assignedProjectIDs = decodedAssignedProjectIDs
        let decodedFavoriteProjectIDs = (try container.decodeIfPresent([UUID].self, forKey: .favoriteProjectIDs) ?? [])
            .removingDuplicateValues()
        favoriteProjectIDs = decodedFavoriteProjectIDs
            .filter { decodedAssignedProjectIDs.contains($0) }

        performanceEvaluations = (try container.decodeIfPresent([ResourcePerformanceEvaluation].self, forKey: .performanceEvaluations) ?? [])
            .sorted { $0.evaluatedAt < $1.evaluatedAt }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(jobTitle, forKey: .jobTitle)
        try container.encode(department, forKey: .department)
        try container.encodeIfPresent(nom, forKey: .nom)
        try container.encodeIfPresent(parentDescription, forKey: .parentDescription)
        try container.encodeIfPresent(primaryResourceRole, forKey: .primaryResourceRole)
        try container.encodeIfPresent(resourceRoles, forKey: .resourceRoles)
        try container.encodeIfPresent(organizationalResource, forKey: .organizationalResource)
        try container.encodeIfPresent(competence1, forKey: .competence1)
        try container.encodeIfPresent(resourceCalendar, forKey: .resourceCalendar)
        try container.encodeIfPresent(resourceStartDate, forKey: .resourceStartDate)
        try container.encodeIfPresent(resourceFinishDate, forKey: .resourceFinishDate)
        try container.encodeIfPresent(responsableOperationnel, forKey: .responsableOperationnel)
        try container.encodeIfPresent(responsableInterne, forKey: .responsableInterne)
        try container.encodeIfPresent(localisation, forKey: .localisation)
        try container.encodeIfPresent(typeDeRessource, forKey: .typeDeRessource)
        try container.encodeIfPresent(journeesTempsPartiel, forKey: .journeesTempsPartiel)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(engagement, forKey: .engagement)
        try container.encode(status, forKey: .status)
        try container.encode(allocationPercent, forKey: .allocationPercent)
        try container.encode(assignedProjectIDs, forKey: .assignedProjectIDs)
        try container.encode(favoriteProjectIDs, forKey: .favoriteProjectIDs)
        try container.encode(assignedProjectIDs.first, forKey: .assignedProjectID)
        try container.encode(performanceEvaluations, forKey: .performanceEvaluations)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

extension Resource {
    var allocationLabel: String {
        "\(allocationPercent)%"
    }

    func isFavorite(in projectID: UUID) -> Bool {
        favoriteProjectIDs.contains(projectID)
    }

    var displayName: String {
        let value = nom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? fullName : value
    }

    var displayPrimaryRole: String {
        let primary = primaryResourceRole?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if primary.isEmpty == false { return primary }

        let secondary = resourceRoles?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if secondary.isEmpty == false { return secondary }

        return jobTitle
    }

    var displayDepartment: String {
        let parent = parentDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if parent.isEmpty == false { return parent }

        let organizational = organizationalResource?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if organizational.isEmpty == false { return organizational }

        return department
    }

    var normalizedRoleKeywords: [String] {
        let candidates = [
            primaryResourceRole ?? "",
            resourceRoles ?? "",
            jobTitle
        ]

        let separators = CharacterSet(charactersIn: ",;/|•\n")
        return candidates
            .flatMap { value -> [String] in
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleaned.isEmpty == false else { return [] }

                let splitTokens = cleaned
                    .components(separatedBy: separators)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }

                return [cleaned] + splitTokens
            }
            .map { normalizeRoleToken($0) }
            .filter { $0.isEmpty == false }
    }

    var criticalRoles: [CriticalProjectRole] {
        CriticalProjectRole.allCases.filter { role in
            normalizedRoleKeywords.contains { token in
                role.matches(token)
            }
        }
    }
}

struct ResourceRoleCoverage: Identifiable, Hashable {
    let role: CriticalProjectRole
    let assignedResources: [Resource]

    var id: String { role.id }

    var isCovered: Bool {
        assignedResources.isEmpty == false
    }

    var activeResources: [Resource] {
        assignedResources.filter(\.isActivelyContributing)
    }
}

struct ResourceProfilingReport: Hashable {
    let requiredRoles: [CriticalProjectRole]
    let roleCoverage: [ResourceRoleCoverage]

    var coveredCount: Int {
        roleCoverage.filter(\.isCovered).count
    }

    var completionRatio: Double {
        guard requiredRoles.isEmpty == false else { return 1 }
        return Double(coveredCount) / Double(requiredRoles.count)
    }

    var completionPercent: Int {
        Int((completionRatio * 100).rounded())
    }

    var missingRoles: [CriticalProjectRole] {
        roleCoverage.filter { $0.isCovered == false }.map(\.role)
    }

    var activeContributorCount: Int {
        roleCoverage.reduce(0) { $0 + $1.activeResources.count }
    }
}

enum ResourceEvaluationScale: Int, CaseIterable, Codable, Hashable, Identifiable {
    case lacunaire = 1
    case fragile = 2
    case satisfaisant = 3
    case solide = 4
    case expert = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .lacunaire:
            "Lacunaire"
        case .fragile:
            "Fragile"
        case .satisfaisant:
            "Satisfaisant"
        case .solide:
            "Solide"
        case .expert:
            "Expert"
        }
    }
}

enum ResourceEvaluationCriterion: String, CaseIterable, Codable, Hashable, Identifiable {
    case qualityDeliverable
    case deadlineCompliance
    case technicalFit
    case reliability
    case collaboration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .qualityDeliverable:
            "Qualité du livrable"
        case .deadlineCompliance:
            "Respect des délais"
        case .technicalFit:
            "Adéquation technique"
        case .reliability:
            "Fiabilité"
        case .collaboration:
            "Collaboration"
        }
    }

    func weight(for phase: ProjectPhase?) -> Double {
        switch phase {
        case .cadrage:
            switch self {
            case .qualityDeliverable:
                return 0.20
            case .deadlineCompliance:
                return 0.15
            case .technicalFit:
                return 0.25
            case .reliability:
                return 0.10
            case .collaboration:
                return 0.30
            }
        case .planning:
            switch self {
            case .qualityDeliverable:
                return 0.25
            case .deadlineCompliance:
                return 0.20
            case .technicalFit:
                return 0.25
            case .reliability:
                return 0.15
            case .collaboration:
                return 0.15
            }
        case .delivery:
            switch self {
            case .qualityDeliverable:
                return 0.25
            case .deadlineCompliance:
                return 0.30
            case .technicalFit:
                return 0.20
            case .reliability:
                return 0.20
            case .collaboration:
                return 0.05
            }
        case .stabilisation:
            switch self {
            case .qualityDeliverable:
                return 0.25
            case .deadlineCompliance:
                return 0.15
            case .technicalFit:
                return 0.20
            case .reliability:
                return 0.35
            case .collaboration:
                return 0.05
            }
        case nil:
            return 0.20
        }
    }
}

struct ResourceCriterionScore: Codable, Hashable, Identifiable {
    var id: String { criterion.id }
    let criterion: ResourceEvaluationCriterion
    let score: ResourceEvaluationScale
}

struct ResourcePerformanceEvaluation: Identifiable, Codable, Hashable {
    let id: UUID
    let evaluatedAt: Date
    let milestone: String
    let evaluator: String
    let projectID: UUID?
    let projectPhase: ProjectPhase?
    let criterionScores: [ResourceCriterionScore]
    let weightedScore: Double
    let comment: String

    init(
        id: UUID = UUID(),
        evaluatedAt: Date = .now,
        milestone: String,
        evaluator: String,
        projectID: UUID?,
        projectPhase: ProjectPhase?,
        criterionScores: [ResourceCriterionScore],
        comment: String
    ) {
        self.id = id
        self.evaluatedAt = evaluatedAt
        self.milestone = milestone
        self.evaluator = evaluator
        self.projectID = projectID
        self.projectPhase = projectPhase
        self.criterionScores = criterionScores.sorted { $0.criterion.rawValue < $1.criterion.rawValue }
        self.weightedScore = ResourcePerformanceEvaluation.computeWeightedScore(scores: criterionScores, phase: projectPhase)
        self.comment = comment
    }

    static func computeWeightedScore(scores: [ResourceCriterionScore], phase: ProjectPhase?) -> Double {
        guard scores.isEmpty == false else { return 0 }
        let weightedTotal = scores.reduce(0.0) { partial, item in
            partial + (Double(item.score.rawValue) * item.criterion.weight(for: phase))
        }
        return min(max(weightedTotal, 1), 5)
    }
}

enum ResourcePerformanceTrend: String, Hashable {
    case stable
    case improving
    case degrading

    var label: String {
        switch self {
        case .stable:
            "Stable"
        case .improving:
            "En amélioration"
        case .degrading:
            "En dégradation"
        }
    }
}

struct ResourcePerformanceAlert: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case sustainedDegradation
        case belowGroupAverage

        var label: String {
            switch self {
            case .sustainedDegradation:
                "Dégradation soutenue"
            case .belowGroupAverage:
                "Écart significatif au groupe"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

struct ResourcePerformanceSnapshot: Hashable {
    let resourceID: UUID
    let resourceName: String
    let latestScore: Double?
    let trend: ResourcePerformanceTrend
    let alerts: [ResourcePerformanceAlert]
}

enum CriticalProjectRole: String, CaseIterable, Identifiable, Hashable {
    case projectManager
    case technicalArchitect
    case solutionArchitect
    case pmoProgramManager
    case changeManager
    case sponsor
    case qaLead
    case businessAnalyst
    case developerEngineer
    case releaseManager
    case transitionLead
    case productOwner
    case systemsEngineer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .projectManager:
            "Chef de Projet (Project Manager)"
        case .technicalArchitect:
            "Architecte Technique (Technical Architect)"
        case .solutionArchitect:
            "Architecte de Solution (Solution Architect)"
        case .pmoProgramManager:
            "PMO / Chef de Programme (Program Manager)"
        case .changeManager:
            "Gestionnaire du Changement (Change Manager)"
        case .sponsor:
            "Sponsor / Commanditaire (Sponsor)"
        case .qaLead:
            "Coordinateur de Tests / QA Lead (Testing Coordinator)"
        case .businessAnalyst:
            "Analyste Fonctionnel (Business Analyst)"
        case .developerEngineer:
            "Développeur / Ingénieur (Developer/Engineer)"
        case .releaseManager:
            "Gestionnaire de Release (Release Manager)"
        case .transitionLead:
            "Responsable de Transition (Transition Lead)"
        case .productOwner:
            "Propriétaire du Produit (Product Owner)"
        case .systemsEngineer:
            "Ingénieur Système (Systems Engineer)"
        }
    }

    var matchingKeywords: [String] {
        switch self {
        case .projectManager:
            ["chef de projet", "project manager", "pm"]
        case .technicalArchitect:
            ["architecte technique", "technical architect"]
        case .solutionArchitect:
            ["architecte de solution", "solution architect", "enterprise architect"]
        case .pmoProgramManager:
            ["pmo", "project management office", "chef de programme", "program manager", "programme manager"]
        case .changeManager:
            ["gestionnaire du changement", "change manager", "change lead"]
        case .sponsor:
            ["sponsor", "commanditaire", "executive sponsor"]
        case .qaLead:
            ["coordinateur de tests", "qa lead", "testing coordinator", "test lead", "quality assurance"]
        case .businessAnalyst:
            ["analyste fonctionnel", "business analyst", "ba"]
        case .developerEngineer:
            ["developpeur", "développeur", "developer", "engineer", "ingenieur", "ingénieur", "software engineer"]
        case .releaseManager:
            ["gestionnaire de release", "release manager", "release lead"]
        case .transitionLead:
            ["responsable de transition", "transition lead", "transition manager"]
        case .productOwner:
            ["proprietaire du produit", "propriétaire du produit", "product owner", "po"]
        case .systemsEngineer:
            ["ingenieur systeme", "ingénieur système", "systems engineer", "system engineer"]
        }
    }

    func matches(_ normalizedToken: String) -> Bool {
        guard normalizedToken.isEmpty == false else { return false }

        return matchingKeywords
            .map(normalizeRoleToken(_:))
            .contains { keyword in
                guard keyword.isEmpty == false else { return false }
                return normalizedToken.contains(keyword) || keyword.contains(normalizedToken)
            }
    }
}

private func normalizeRoleToken(_ value: String) -> String {
    value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

extension Resource {
    var isActivelyContributing: Bool {
        status == .active || status == .partiallyAvailable
    }
}

private extension Array where Element: Hashable {
    func removingDuplicateValues() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

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

enum ResourceEngagement: String, Codable, CaseIterable, Identifiable {
    case internalEmployee
    case externalConsultant
    case freelancer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .internalEmployee:
            "Interne"
        case .externalConsultant:
            "Prestataire"
        case .freelancer:
            "Freelance"
        }
    }
}

enum ResourceStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case partiallyAvailable
    case onLeave
    case offboarded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active:
            "Disponible"
        case .partiallyAvailable:
            "Partiel"
        case .onLeave:
            "Absent"
        case .offboarded:
            "Sorti"
        }
    }

    var tintName: String {
        colorToken.rawValue
    }
}

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
        case id
        case projectID
        case scenarioID
        case parentActivityID
        case hierarchyLevel
        case title
        case estimatedStartDate
        case estimatedEndDate
        case actualEndDate
        case predecessorActivityIDs
        case isMilestone
        case linkedDeliverableIDs
        case createdAt
        case updatedAt
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

struct ProjectMeeting: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var projectID: UUID?
    var meetingAt: Date
    var durationMinutes: Int
    var mode: MeetingMode
    var organizer: String
    var participants: String
    var locationOrLink: String
    var notes: String
    var transcript: String
    var aiSummary: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        projectID: UUID? = nil,
        meetingAt: Date,
        durationMinutes: Int = 60,
        mode: MeetingMode = .virtual,
        organizer: String = "",
        participants: String = "",
        locationOrLink: String = "",
        notes: String = "",
        transcript: String,
        aiSummary: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.meetingAt = meetingAt
        self.durationMinutes = max(durationMinutes, 1)
        self.mode = mode
        self.organizer = organizer
        self.participants = participants
        self.locationOrLink = locationOrLink
        self.notes = notes
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectMeeting {
    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Réunion sans titre" : cleaned
    }
}

enum MeetingMode: String, Codable, CaseIterable, Identifiable {
    case physical
    case virtual
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .physical:
            "Physique"
        case .virtual:
            "Virtuelle"
        case .hybrid:
            "Hybride"
        }
    }

    var systemImage: String {
        switch self {
        case .physical:
            "person.2.fill"
        case .virtual:
            "video.fill"
        case .hybrid:
            "person.2.wave.2.fill"
        }
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
