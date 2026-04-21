import Foundation

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
