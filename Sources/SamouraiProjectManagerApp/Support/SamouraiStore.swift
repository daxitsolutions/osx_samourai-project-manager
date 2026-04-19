import Foundation
import Observation

struct SamouraiDatabase: Codable {
    var projects: [Project]
    var resources: [Resource]
    var unassignedRisks: [Risk]
    var activities: [ProjectActivity]
    var events: [ProjectEvent]
    var actions: [ProjectAction]
    var meetings: [ProjectMeeting]
    var decisions: [ProjectDecision]
    var governanceReports: [GovernanceReportRecord]

    init(
        projects: [Project],
        resources: [Resource],
        unassignedRisks: [Risk] = [],
        activities: [ProjectActivity] = [],
        events: [ProjectEvent] = [],
        actions: [ProjectAction] = [],
        meetings: [ProjectMeeting] = [],
        decisions: [ProjectDecision] = [],
        governanceReports: [GovernanceReportRecord] = []
    ) {
        self.projects = projects
        self.resources = resources
        self.unassignedRisks = unassignedRisks
        self.activities = activities
        self.events = events
        self.actions = actions
        self.meetings = meetings
        self.decisions = decisions
        self.governanceReports = governanceReports
    }

    private enum CodingKeys: String, CodingKey {
        case projects
        case resources
        case unassignedRisks
        case activities
        case events
        case actions
        case meetings
        case decisions
        case governanceReports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decode([Project].self, forKey: .projects)
        resources = try container.decode([Resource].self, forKey: .resources)
        unassignedRisks = try container.decodeIfPresent([Risk].self, forKey: .unassignedRisks) ?? []
        activities = try container.decodeIfPresent([ProjectActivity].self, forKey: .activities) ?? []
        events = try container.decodeIfPresent([ProjectEvent].self, forKey: .events) ?? []
        actions = try container.decodeIfPresent([ProjectAction].self, forKey: .actions) ?? []
        meetings = try container.decodeIfPresent([ProjectMeeting].self, forKey: .meetings) ?? []
        decisions = try container.decodeIfPresent([ProjectDecision].self, forKey: .decisions) ?? []
        governanceReports = try container.decodeIfPresent([GovernanceReportRecord].self, forKey: .governanceReports) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projects, forKey: .projects)
        try container.encode(resources, forKey: .resources)
        try container.encode(unassignedRisks, forKey: .unassignedRisks)
        try container.encode(activities, forKey: .activities)
        try container.encode(events, forKey: .events)
        try container.encode(actions, forKey: .actions)
        try container.encode(meetings, forKey: .meetings)
        try container.encode(decisions, forKey: .decisions)
        try container.encode(governanceReports, forKey: .governanceReports)
    }

    static let empty = SamouraiDatabase(projects: [], resources: [])
}

struct SamouraiBackupEnvelope: Codable {
    static let formatIdentifier = "samourai.project-manager.backup"
    static let currentSchemaVersion = 1

    let format: String
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let database: SamouraiDatabase

    init(
        schemaVersion: Int = SamouraiBackupEnvelope.currentSchemaVersion,
        exportedAt: Date = .now,
        appVersion: String,
        database: SamouraiDatabase
    ) {
        self.format = SamouraiBackupEnvelope.formatIdentifier
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.database = database
    }
}

enum SamouraiBackupError: LocalizedError {
    case invalidFormat
    case unsupportedSchemaVersion(Int)
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "Fichier de sauvegarde invalide ou non reconnu."
        case .unsupportedSchemaVersion(let version):
            "Version de schéma non supportée (\(version)). Mets à jour l'application pour restaurer ce backup."
        case .invalidPayload(let details):
            "Sauvegarde corrompue : \(details)"
        }
    }
}

struct SamouraiRestoreResult {
    let projectCount: Int
    let resourceCount: Int
    let riskCount: Int
    let activityCount: Int
    let eventCount: Int
    let actionCount: Int
    let meetingCount: Int
    let decisionCount: Int
    let exportedAt: Date
    let sourceAppVersion: String

    var summary: String {
        "\(projectCount) projet(s), \(resourceCount) ressource(s), \(riskCount) risque(s), \(activityCount) activité(s), \(eventCount) événement(s), \(actionCount) action(s), \(meetingCount) réunion(s), \(decisionCount) décision(s) restaurée(s)."
    }
}

struct ResourceImportDraft {
    let nom: String?
    let parentDescription: String?
    let primaryResourceRole: String?
    let resourceRoles: String?
    let organizationalResource: String?
    let competence1: String?
    let resourceCalendar: String?
    let resourceStartDate: Date?
    let resourceFinishDate: Date?
    let responsableOperationnel: String?
    let responsableInterne: String?
    let localisation: String?
    let typeDeRessource: String?
    let journeesTempsPartiel: String?
    let engagement: ResourceEngagement
    let status: ResourceStatus
    let allocationPercent: Int
    let notes: String
    let sourceRowNumber: Int
}

struct ResourceImportResult {
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let firstImportedOrUpdatedResourceID: UUID?

    var summary: String {
        "\(importedCount) créée(s), \(updatedCount) mise(s) à jour, \(skippedCount) ignorée(s)."
    }
}

struct RiskImportDraft {
    let externalID: String?
    let projectNames: String?
    let detectedBy: String?
    let assignedTo: String?
    let dateCreated: Date?
    let lastModifiedAt: Date?
    let riskType: String?
    let response: String?
    let riskTitle: String?
    let riskOrigin: String?
    let impactDescription: String?
    let counterMeasure: String?
    let followUpComment: String?
    let proximity: String?
    let probability: String?
    let impactScope: String?
    let impactBudget: String?
    let impactPlanning: String?
    let impactResources: String?
    let impactTransition: String?
    let impactSecurityIT: String?
    let escalationLevel: String?
    let riskStatus: String?
    let score0to10: Double?
    let sourceRowNumber: Int
}

struct RiskImportResult {
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let firstImportedOrUpdatedRiskID: UUID?

    var summary: String {
        "\(importedCount) créé(s), \(updatedCount) mis à jour, \(skippedCount) ignoré(s)."
    }
}

struct ResourceImportFieldChange: Identifiable {
    let id = UUID()
    let fieldLabel: String
    let oldValue: String
    let newValue: String
}

enum ResourceImportReviewAction: String {
    case create
    case update
    case noChange
    case skipped
}

struct ResourceImportReviewItem: Identifiable {
    let id = UUID()
    let sourceRowNumber: Int
    let action: ResourceImportReviewAction
    let resourceID: UUID?
    let displayName: String
    let changes: [ResourceImportFieldChange]
    let proposedResource: Resource?
    let isExistingResource: Bool
}

struct ResourceImportDecision {
    let reviewItemID: UUID
    let shouldApply: Bool
}

enum ActionFlowFilter: String, CaseIterable, Identifiable {
    case all
    case incomingLeMans
    case pushedAutomatic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            "Toutes"
        case .incomingLeMans:
            "Le Mans"
        case .pushedAutomatic:
            "Diffusées auto"
        }
    }
}

private struct NormalizedResourceFields {
    let fullName: String
    let jobTitle: String
    let department: String
    let nom: String?
    let parentDescription: String?
    let primaryResourceRole: String?
    let resourceRoles: String?
    let organizationalResource: String?
    let competence1: String?
    let resourceCalendar: String?
    let resourceStartDate: Date?
    let resourceFinishDate: Date?
    let responsableOperationnel: String?
    let responsableInterne: String?
    let localisation: String?
    let typeDeRessource: String?
    let journeesTempsPartiel: String?
    let engagement: ResourceEngagement
    let status: ResourceStatus
    let allocationPercent: Int
}

actor SamouraiPersistence {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var fileURL: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDirectory = baseURL.appending(path: "SamouraiProjectManager", directoryHint: .isDirectory)
        return appDirectory.appending(path: "projects.json")
    }

    func load() throws -> SamouraiDatabase {
        let url = fileURL
        guard fileManager.fileExists(atPath: url.path()) else {
            return .empty
        }

        let data = try Data(contentsOf: url)
        if let database = try? decoder.decode(SamouraiDatabase.self, from: data) {
            return database
        }

        let legacyProjects = try decoder.decode([Project].self, from: data)
        return SamouraiDatabase(projects: legacyProjects, resources: [])
    }

    func save(_ database: SamouraiDatabase) throws {
        let url = fileURL
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(database)
        try data.write(to: url, options: [.atomic])
    }
}

@MainActor
@Observable
final class SamouraiStore {
    private let persistence = SamouraiPersistence()
    private let backupEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let backupDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private(set) var projects: [Project] = []
    private(set) var resources: [Resource] = []
    private(set) var unassignedRisks: [Risk] = []
    private(set) var activities: [ProjectActivity] = []
    private(set) var events: [ProjectEvent] = []
    private(set) var actions: [ProjectAction] = []
    private(set) var meetings: [ProjectMeeting] = []
    private(set) var decisions: [ProjectDecision] = []
    private(set) var governanceReports: [GovernanceReportRecord] = []
    private(set) var hasLoaded = false
    var lastErrorMessage: String?

    var risks: [RiskEntry] {
        let projectRisks = projects
            .flatMap { project in
                project.risks.map { RiskEntry(projectID: project.id, projectName: project.name, risk: $0) }
            }

        let orphanRisks = unassignedRisks.map {
            RiskEntry(
                projectID: nil,
                projectName: ($0.projectNames?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0.projectNames! : "Sans projet"),
                risk: $0
            )
        }

        return (projectRisks + orphanRisks).sorted {
            if $0.risk.severity.sortWeight == $1.risk.severity.sortWeight {
                return ($0.risk.dueDate ?? .distantFuture) < ($1.risk.dueDate ?? .distantFuture)
            }
            return $0.risk.severity.sortWeight > $1.risk.severity.sortWeight
        }
    }

    var deliverables: [DeliverableEntry] {
        projects
            .flatMap { project in
                project.deliverables.map { DeliverableEntry(projectID: project.id, projectName: project.name, deliverable: $0) }
            }
            .sorted {
                if $0.deliverable.dueDate == $1.deliverable.dueDate {
                    return $0.deliverable.title.localizedStandardCompare($1.deliverable.title) == .orderedAscending
                }
                return $0.deliverable.dueDate < $1.deliverable.dueDate
            }
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else { return }
        hasLoaded = true

        do {
            let database = try await persistence.load()
            if database.projects.isEmpty, database.resources.isEmpty {
                let seededProjects = SamouraiSeedFactory.makeDemoProjects()
                let seededResources = SamouraiSeedFactory.makeDemoResources(projects: seededProjects)
                projects = sortProjects(seededProjects)
                resources = sortResources(seededResources)
                unassignedRisks = []
                activities = []
                events = []
                actions = []
                meetings = []
                decisions = []
                governanceReports = []
                try await persistence.save(makeDatabase())
            } else {
                projects = sortProjects(database.projects)
                resources = sortResources(sanitizeResourceAssignments(database.resources, projectIDs: Set(projects.map(\.id))))
                unassignedRisks = sortStandaloneRisks(database.unassignedRisks)
                activities = sortActivities(sanitizeActivities(database.activities, projectIDs: Set(projects.map(\.id))))
                events = sortEvents(
                    sanitizeEvents(
                        database.events,
                        projectIDs: Set(projects.map(\.id)),
                        resourceIDs: Set(resources.map(\.id))
                    )
                )
                let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
                actions = sortActions(
                    sanitizeActions(
                        database.actions,
                        projectIDs: Set(projects.map(\.id)),
                        activitiesByID: activitiesByID
                    )
                )
                meetings = sortMeetings(
                    sanitizeMeetings(database.meetings, projectIDs: Set(projects.map(\.id)))
                )
                decisions = sortDecisions(
                    sanitizeDecisions(
                        database.decisions,
                        projectIDs: Set(projects.map(\.id)),
                        meetingIDs: Set(meetings.map(\.id)),
                        eventIDs: Set(events.map(\.id)),
                        resourceIDs: Set(resources.map(\.id))
                    )
                )
                governanceReports = sortGovernanceReports(
                    sanitizeGovernanceReports(database.governanceReports, projectIDs: Set(projects.map(\.id)))
                )
            }
        } catch {
            lastErrorMessage = "Chargement impossible : \(error.localizedDescription)"

            if projects.isEmpty {
                let seededProjects = SamouraiSeedFactory.makeDemoProjects()
                let seededResources = SamouraiSeedFactory.makeDemoResources(projects: seededProjects)
                projects = sortProjects(seededProjects)
                resources = sortResources(seededResources)
                unassignedRisks = []
                activities = []
                events = []
                actions = []
                meetings = []
                decisions = []
                governanceReports = []
                do {
                    try await persistence.save(makeDatabase())
                } catch {
                    lastErrorMessage = "Persistance impossible : \(error.localizedDescription)"
                }
            }
        }
    }

    func project(with id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func resource(with id: UUID) -> Resource? {
        resources.first { $0.id == id }
    }

    func risk(with id: UUID) -> Risk? {
        if let projectRisk = projects.lazy.flatMap(\.risks).first(where: { $0.id == id }) {
            return projectRisk
        }
        return unassignedRisks.first { $0.id == id }
    }

    func event(with id: UUID) -> ProjectEvent? {
        events.first { $0.id == id }
    }

    func action(with id: UUID) -> ProjectAction? {
        actions.first { $0.id == id }
    }

    func meeting(with id: UUID) -> ProjectMeeting? {
        meetings.first { $0.id == id }
    }

    func decision(with id: UUID) -> ProjectDecision? {
        decisions.first { $0.id == id }
    }

    func activity(with id: UUID) -> ProjectActivity? {
        activities.first { $0.id == id }
    }

    func activities(for projectID: UUID) -> [ProjectActivity] {
        activities.filter { $0.projectID == projectID }
    }

    func activityProgress(activityID: UUID) -> Double {
        guard let activity = activity(with: activityID) else { return 0 }
        return activityProgress(for: activity)
    }

    func exportBackupData() throws -> Data {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let envelope = SamouraiBackupEnvelope(
            appVersion: appVersion,
            database: makeDatabase()
        )
        return try backupEncoder.encode(envelope)
    }

    func restoreBackupData(_ data: Data) throws -> SamouraiRestoreResult {
        let envelope: SamouraiBackupEnvelope
        do {
            envelope = try backupDecoder.decode(SamouraiBackupEnvelope.self, from: data)
        } catch {
            throw SamouraiBackupError.invalidFormat
        }

        guard envelope.format == SamouraiBackupEnvelope.formatIdentifier else {
            throw SamouraiBackupError.invalidFormat
        }

        guard envelope.schemaVersion == SamouraiBackupEnvelope.currentSchemaVersion else {
            throw SamouraiBackupError.unsupportedSchemaVersion(envelope.schemaVersion)
        }

        let normalized = try validatedDatabase(from: envelope.database)

        projects = sortProjects(normalized.projects)
        resources = sortResources(sanitizeResourceAssignments(normalized.resources, projectIDs: Set(normalized.projects.map(\.id))))
        unassignedRisks = sortStandaloneRisks(normalized.unassignedRisks)
        activities = sortActivities(sanitizeActivities(normalized.activities, projectIDs: Set(normalized.projects.map(\.id))))
        events = sortEvents(
            sanitizeEvents(
                normalized.events,
                projectIDs: Set(normalized.projects.map(\.id)),
                resourceIDs: Set(normalized.resources.map(\.id))
            )
        )
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        actions = sortActions(
            sanitizeActions(
                normalized.actions,
                projectIDs: Set(normalized.projects.map(\.id)),
                activitiesByID: activitiesByID
            )
        )
        meetings = sortMeetings(
            sanitizeMeetings(normalized.meetings, projectIDs: Set(normalized.projects.map(\.id)))
        )
        decisions = sortDecisions(
            sanitizeDecisions(
                normalized.decisions,
                projectIDs: Set(normalized.projects.map(\.id)),
                meetingIDs: Set(normalized.meetings.map(\.id)),
                eventIDs: Set(normalized.events.map(\.id)),
                resourceIDs: Set(normalized.resources.map(\.id))
            )
        )
        governanceReports = sortGovernanceReports(
            sanitizeGovernanceReports(
                normalized.governanceReports,
                projectIDs: Set(normalized.projects.map(\.id))
            )
        )
        persist()

        let riskCount = normalized.projects.reduce(0) { $0 + $1.risks.count } + normalized.unassignedRisks.count
        return SamouraiRestoreResult(
            projectCount: normalized.projects.count,
            resourceCount: normalized.resources.count,
            riskCount: riskCount,
            activityCount: normalized.activities.count,
            eventCount: normalized.events.count,
            actionCount: normalized.actions.count,
            meetingCount: normalized.meetings.count,
            decisionCount: normalized.decisions.count,
            exportedAt: envelope.exportedAt,
            sourceAppVersion: envelope.appVersion
        )
    }

    func resources(for projectID: UUID) -> [Resource] {
        resources
            .filter { $0.assignedProjectIDs.contains(projectID) }
            .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    func resourceProfiling(for projectID: UUID?) -> ResourceProfilingReport {
        let scopedResources: [Resource]
        if let projectID {
            scopedResources = resources(for: projectID)
        } else {
            scopedResources = resources
        }

        let coverage = CriticalProjectRole.allCases.map { role in
            let assigned = scopedResources
                .filter { $0.criticalRoles.contains(role) }
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return ResourceRoleCoverage(role: role, assignedResources: assigned)
        }

        return ResourceProfilingReport(
            requiredRoles: CriticalProjectRole.allCases,
            roleCoverage: coverage
        )
    }

    func addResourceEvaluation(
        resourceID: UUID,
        projectID: UUID?,
        milestone: String,
        evaluator: String,
        comment: String,
        criterionScores: [ResourceCriterionScore],
        evaluatedAt: Date = .now
    ) {
        guard let resourceIndex = resources.firstIndex(where: { $0.id == resourceID }) else { return }
        let cleanedMilestone = milestone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEvaluator = evaluator.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedComment.isEmpty == false else { return }

        let scopedProjectID = sanitizedProjectID(projectID)
        let scopedPhase = scopedProjectID.flatMap { project(with: $0)?.phase }
        let evaluation = ResourcePerformanceEvaluation(
            evaluatedAt: evaluatedAt,
            milestone: cleanedMilestone.isEmpty ? "Point de contrôle" : cleanedMilestone,
            evaluator: cleanedEvaluator.isEmpty ? "Chef de Projet" : cleanedEvaluator,
            projectID: scopedProjectID,
            projectPhase: scopedPhase,
            criterionScores: normalizedCriterionScores(criterionScores),
            comment: cleanedComment
        )

        resources[resourceIndex].performanceEvaluations.append(evaluation)
        resources[resourceIndex].performanceEvaluations.sort { $0.evaluatedAt < $1.evaluatedAt }
        resources[resourceIndex].updatedAt = .now
        resources = sortResources(resources)
        persist()
    }

    func performanceSnapshot(for resourceID: UUID, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot? {
        guard let resource = resource(with: resourceID) else { return nil }
        return makePerformanceSnapshot(for: resource, scopedProjectID: scopedProjectID)
    }

    func comparativePerformance(for projectID: UUID?) -> [ResourcePerformanceSnapshot] {
        let scopedResources: [Resource]
        if let projectID {
            scopedResources = resources(for: projectID)
        } else {
            scopedResources = resources
        }

        return scopedResources
            .map { makePerformanceSnapshot(for: $0, scopedProjectID: projectID) }
            .sorted { lhs, rhs in
                let lhsRisk = lhs.alerts.isEmpty ? 0 : 1
                let rhsRisk = rhs.alerts.isEmpty ? 0 : 1
                if lhsRisk != rhsRisk { return lhsRisk > rhsRisk }

                switch (lhs.latestScore, rhs.latestScore) {
                case let (.some(left), .some(right)):
                    if left == right {
                        return lhs.resourceName.localizedStandardCompare(rhs.resourceName) == .orderedAscending
                    }
                    return left < right
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return lhs.resourceName.localizedStandardCompare(rhs.resourceName) == .orderedAscending
                }
            }
    }

    func governanceReport(
        cadence: ReportingCadence,
        scopedProjectIDs: [UUID]?,
        scopeLabel: String,
        referenceDate: Date = .now
    ) -> GovernanceReport {
        let period = reportingPeriod(cadence: cadence, referenceDate: referenceDate)
        let previousPeriod = reportingPreviousPeriod(current: period)
        let scopedProjects = reportingScopedProjects(scopedProjectIDs: scopedProjectIDs)
        let scopedProjectIDSet = Set(scopedProjects.map(\.id))

        let scopedActivities = activities.filter { scopedProjectIDSet.contains($0.projectID) }
        let scopedActions = actions.filter { action in
            guard let projectID = action.projectID else { return false }
            return scopedProjectIDSet.contains(projectID)
        }
        let scopedDecisions = decisions.filter { decision in
            guard let projectID = decision.projectID else { return false }
            return scopedProjectIDSet.contains(projectID)
        }

        let executiveSummary = GovernanceReport.ExecutiveSummary(
            ragStatus: reportingGlobalHealth(for: scopedProjects),
            progressPercent: reportingGlobalProgressPercent(projects: scopedProjects, activities: scopedActivities),
            criticalRiskCount: reportingCriticalRiskCount(projects: scopedProjects, asOf: period.endExclusive),
            criticalRiskDeltaFromPreviousPeriod:
                reportingCriticalRiskCount(projects: scopedProjects, asOf: period.endExclusive)
                - reportingCriticalRiskCount(projects: scopedProjects, asOf: previousPeriod.endExclusive),
            testsAveragePercent: reportingTestsAveragePercent(projects: scopedProjects),
            blockedTestingPhases: scopedProjects.reduce(0) { $0 + $1.blockedTestingPhaseCount },
            testsRAGStatus: reportingGlobalTestsRAGStatus(projects: scopedProjects)
        )

        let accomplishments = reportingAccomplishments(
            projects: scopedProjects,
            activities: scopedActivities,
            decisions: scopedDecisions,
            period: period
        )

        let variancesAndChanges = reportingVariancesAndChanges(
            projects: scopedProjects,
            actions: scopedActions,
            period: period,
            previousPeriod: previousPeriod,
            referenceDate: referenceDate
        )

        let nextSteps = reportingNextSteps(
            projects: scopedProjects,
            activities: scopedActivities,
            actions: scopedActions,
            referenceDate: referenceDate,
            horizonDays: cadence.periodHorizonDays
        )

        return GovernanceReport(
            cadence: cadence,
            scopeLabel: scopeLabel,
            periodStart: period.start,
            periodEndExclusive: period.endExclusive,
            generatedAt: .now,
            executiveSummary: executiveSummary,
            accomplishments: accomplishments,
            variancesAndChanges: variancesAndChanges,
            nextSteps: nextSteps
        )
    }

    func governanceReportArchive(scopedProjectID: UUID? = nil) -> [GovernanceReportRecord] {
        guard let scopedProjectID else { return governanceReports }
        return governanceReports.filter { record in
            guard let scoped = record.scopedProjectIDs else { return true }
            return scoped.contains(scopedProjectID)
        }
    }

    @discardableResult
    func saveGovernanceReportRecord(
        generatedReport: GovernanceReport,
        scopedProjectIDs: [UUID]?,
        executiveSummaryPMNote: String,
        planningActionsPMNote: String,
        conclusionPMMessage: String
    ) -> UUID {
        let newRecord = GovernanceReportRecord(
            generatedReport: generatedReport,
            scopedProjectIDs: scopedProjectIDs,
            executiveSummaryPMNote: executiveSummaryPMNote,
            planningActionsPMNote: planningActionsPMNote,
            conclusionPMMessage: conclusionPMMessage
        )
        governanceReports.append(newRecord)
        governanceReports = sortGovernanceReports(governanceReports)
        persist()
        return newRecord.id
    }

    func updateGovernanceReportRecord(
        reportID: UUID,
        executiveSummaryPMNote: String,
        planningActionsPMNote: String,
        conclusionPMMessage: String
    ) {
        guard let index = governanceReports.firstIndex(where: { $0.id == reportID }) else { return }
        governanceReports[index].executiveSummaryPMNote = executiveSummaryPMNote.trimmingCharacters(in: .whitespacesAndNewlines)
        governanceReports[index].planningActionsPMNote = planningActionsPMNote.trimmingCharacters(in: .whitespacesAndNewlines)
        governanceReports[index].conclusionPMMessage = conclusionPMMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        governanceReports[index].updatedAt = .now
        governanceReports = sortGovernanceReports(governanceReports)
        persist()
    }

    func deleteGovernanceReportRecord(reportID: UUID) {
        governanceReports.removeAll { $0.id == reportID }
        governanceReports = sortGovernanceReports(governanceReports)
        persist()
    }

    func events(matching query: String) -> [ProjectEvent] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return events }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalizedToken)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return events }

        return events.filter { event in
            let searchableValues = eventSearchableValues(for: event).map(normalizedToken)
            return terms.allSatisfy { term in
                searchableValues.contains(where: { $0.contains(term) })
            }
        }
    }

    func addEvent(
        title: String,
        details: String,
        source: String,
        priority: EventPriority,
        happenedAt: Date,
        projectID: UUID?,
        resourceIDs: [UUID]
    ) -> UUID {
        let event = ProjectEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            happenedAt: happenedAt,
            projectID: sanitizedProjectID(projectID),
            resourceIDs: sanitizedResourceIDs(resourceIDs)
        )

        events.append(event)
        events = sortEvents(events)
        persist()
        return event.id
    }

    func updateEvent(
        eventID: UUID,
        title: String,
        details: String,
        source: String,
        priority: EventPriority,
        happenedAt: Date,
        projectID: UUID?,
        resourceIDs: [UUID]
    ) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }

        events[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        events[index].details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        events[index].source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        events[index].priority = priority
        events[index].happenedAt = happenedAt
        events[index].projectID = sanitizedProjectID(projectID)
        events[index].resourceIDs = sanitizedResourceIDs(resourceIDs)
        events[index].updatedAt = .now
        events = sortEvents(events)
        persist()
    }

    func deleteEvent(eventID: UUID) {
        events.removeAll { $0.id == eventID }
        decisions = decisions.map { decision in
            var updatedDecision = decision
            updatedDecision.eventIDs.removeAll { $0 == eventID }
            return updatedDecision
        }
        persist()
    }

    func actions(matching query: String, flow: ActionFlowFilter = .all) -> [ProjectAction] {
        let baseActions: [ProjectAction]
        switch flow {
        case .all:
            baseActions = actions
        case .incomingLeMans:
            baseActions = actions.filter { $0.flow == .incomingLeMans }
        case .pushedAutomatic:
            baseActions = actions.filter { $0.flow == .pushedAutomatic }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return baseActions }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalizedToken)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return baseActions }

        return baseActions.filter { action in
            let searchableValues = actionSearchableValues(for: action).map(normalizedToken)
            return terms.allSatisfy { term in
                searchableValues.contains(where: { $0.contains(term) })
            }
        }
    }

    func addAction(
        title: String,
        details: String,
        priority: ActionPriority,
        dueDate: Date,
        flow: ActionFlow,
        projectID: UUID?
    ) -> UUID {
        let action = ProjectAction(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            dueDate: dueDate,
            flow: flow,
            projectID: sanitizedProjectID(projectID)
        )
        actions.append(action)
        actions = sortActions(actions)
        persist()
        return action.id
    }

    func updateAction(
        actionID: UUID,
        title: String,
        details: String,
        priority: ActionPriority,
        dueDate: Date,
        flow: ActionFlow,
        projectID: UUID?
    ) {
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else { return }
        actions[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        actions[index].details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        actions[index].priority = priority
        actions[index].dueDate = dueDate
        actions[index].flow = flow
        actions[index].projectID = sanitizedProjectID(projectID)
        actions[index].updatedAt = .now
        actions = sortActions(actions)
        persist()
    }

    func deleteAction(actionID: UUID) {
        actions.removeAll { $0.id == actionID }
        persist()
    }

    func markActionDone(actionID: UUID, isDone: Bool) {
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else { return }
        actions[index].isDone = isDone
        actions[index].updatedAt = .now
        actions = sortActions(actions)
        persist()
    }

    func assignActionToActivity(actionID: UUID, activityID: UUID?) {
        guard let actionIndex = actions.firstIndex(where: { $0.id == actionID }) else { return }

        if let activityID {
            guard let activity = activity(with: activityID) else { return }
            guard let projectID = actions[actionIndex].projectID, projectID == activity.projectID else { return }
            actions[actionIndex].activityID = activityID
        } else {
            actions[actionIndex].activityID = nil
        }

        actions[actionIndex].updatedAt = .now
        actions = sortActions(actions)
        persist()
    }

    func addActivity(
        projectID: UUID,
        title: String,
        estimatedStartDate: Date,
        estimatedEndDate: Date,
        actualEndDate: Date? = nil,
        linkedActionIDs: [UUID] = [],
        predecessorActivityIDs: [UUID] = [],
        isMilestone: Bool = false,
        linkedDeliverableIDs: [UUID] = []
    ) -> UUID? {
        guard projects.contains(where: { $0.id == projectID }) else { return nil }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedDeliverableIDs = sanitizedDeliverableIDs(projectID: projectID, deliverableIDs: linkedDeliverableIDs)
        let sanitizedPredecessorIDs = sanitizedPredecessorActivityIDs(projectID: projectID, predecessorIDs: predecessorActivityIDs, currentActivityID: nil)
        let activity = ProjectActivity(
            projectID: projectID,
            title: cleanedTitle.isEmpty ? "Activité" : cleanedTitle,
            estimatedStartDate: estimatedStartDate,
            estimatedEndDate: max(estimatedEndDate, estimatedStartDate),
            actualEndDate: actualEndDate,
            predecessorActivityIDs: sanitizedPredecessorIDs,
            isMilestone: isMilestone,
            linkedDeliverableIDs: sanitizedDeliverableIDs
        )

        activities.append(activity)
        activities = sortActivities(activities)
        applyActivityLinks(projectID: projectID, activityID: activity.id, linkedActionIDs: linkedActionIDs)
        persist()
        return activity.id
    }

    func updateActivity(
        activityID: UUID,
        title: String,
        estimatedStartDate: Date,
        estimatedEndDate: Date,
        actualEndDate: Date?,
        linkedActionIDs: [UUID],
        predecessorActivityIDs: [UUID],
        isMilestone: Bool,
        linkedDeliverableIDs: [UUID]
    ) {
        guard let index = activities.firstIndex(where: { $0.id == activityID }) else { return }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        activities[index].title = cleanedTitle.isEmpty ? activities[index].title : cleanedTitle
        activities[index].estimatedStartDate = estimatedStartDate
        activities[index].estimatedEndDate = max(estimatedEndDate, estimatedStartDate)
        activities[index].actualEndDate = actualEndDate
        activities[index].predecessorActivityIDs = sanitizedPredecessorActivityIDs(
            projectID: activities[index].projectID,
            predecessorIDs: predecessorActivityIDs,
            currentActivityID: activityID
        )
        activities[index].isMilestone = isMilestone
        activities[index].linkedDeliverableIDs = sanitizedDeliverableIDs(
            projectID: activities[index].projectID,
            deliverableIDs: linkedDeliverableIDs
        )
        activities[index].updatedAt = .now
        activities = sortActivities(activities)

        applyActivityLinks(
            projectID: activities[index].projectID,
            activityID: activityID,
            linkedActionIDs: linkedActionIDs
        )
        actions = sortActions(actions)
        persist()
    }

    func updateActivityQuick(
        activityID: UUID,
        title: String,
        estimatedStartDate: Date,
        estimatedEndDate: Date,
        actualEndDate: Date?,
        predecessorActivityIDs: [UUID]? = nil,
        isMilestone: Bool? = nil,
        linkedDeliverableIDs: [UUID]? = nil
    ) {
        guard let index = activities.firstIndex(where: { $0.id == activityID }) else { return }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        activities[index].title = cleanedTitle.isEmpty ? activities[index].title : cleanedTitle
        activities[index].estimatedStartDate = estimatedStartDate
        activities[index].estimatedEndDate = max(estimatedEndDate, estimatedStartDate)
        activities[index].actualEndDate = actualEndDate
        if let predecessorActivityIDs {
            activities[index].predecessorActivityIDs = sanitizedPredecessorActivityIDs(
                projectID: activities[index].projectID,
                predecessorIDs: predecessorActivityIDs,
                currentActivityID: activityID
            )
        }
        if let isMilestone {
            activities[index].isMilestone = isMilestone
        }
        if let linkedDeliverableIDs {
            activities[index].linkedDeliverableIDs = sanitizedDeliverableIDs(
                projectID: activities[index].projectID,
                deliverableIDs: linkedDeliverableIDs
            )
        }
        activities[index].updatedAt = .now
        activities = sortActivities(activities)
        persist()
    }

    func linkedDeliverables(for activityID: UUID) -> [Deliverable] {
        guard let activity = activity(with: activityID),
              let project = project(with: activity.projectID)
        else {
            return []
        }

        let map = Dictionary(uniqueKeysWithValues: project.deliverables.map { ($0.id, $0) })
        return activity.linkedDeliverableIDs.compactMap { map[$0] }
    }

    func scopeCoverageReport(projectID: UUID) -> ScopeCoverageReport {
        guard let project = project(with: projectID) else {
            return ScopeCoverageReport(entries: [])
        }

        let majorDeliverables = project.deliverables.filter(\.isMainDeliverable)
        let mappedEntries: [ScopeCoverageEntry] = majorDeliverables.map { deliverable in
            let linkedCount = activities(for: projectID)
                .filter { $0.linkedDeliverableIDs.contains(deliverable.id) }
                .count
            return ScopeCoverageEntry(
                deliverableID: deliverable.id,
                title: deliverable.title,
                isMilestone: deliverable.isMilestone,
                linkedActivityCount: linkedCount
            )
        }
        let entries = mappedEntries.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }

        return ScopeCoverageReport(entries: entries)
    }

    func scopeBaselineExecutionProgress(projectID: UUID) -> ScopeBaselineExecutionProgress? {
        guard let project = project(with: projectID),
              let baseline = project.scopeBaselines.last
        else {
            return nil
        }

        let currentMainDeliverables = project.deliverables.filter(\.isMainDeliverable)
        let snapshotMainDeliverables = baseline.deliverableSnapshots.filter(\.isMainDeliverable)
        let currentByID = Dictionary(uniqueKeysWithValues: currentMainDeliverables.map { ($0.id, $0) })
        let currentByTitle = Dictionary(uniqueKeysWithValues: currentMainDeliverables.map { ($0.title, $0) })

        let acceptedCount = snapshotMainDeliverables.reduce(0) { partial, baselineDeliverable in
            if let match = currentByID[baselineDeliverable.id] ?? currentByTitle[baselineDeliverable.title] {
                return partial + (match.isAccepted ? 1 : 0)
            }
            return partial
        }

        return ScopeBaselineExecutionProgress(
            baselineLabel: baseline.milestoneLabel,
            acceptedCount: acceptedCount,
            totalCount: snapshotMainDeliverables.count
        )
    }

    func createPlanningBaseline(projectID: UUID, label: String, validatedBy: String) -> String? {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return nil }
        let projectActivities = activities(for: projectID)
        guard projectActivities.isEmpty == false else { return nil }

        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedValidatedBy = validatedBy.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseline = PlanningBaseline(
            label: cleanedLabel.isEmpty ? "Planning Baseline" : cleanedLabel,
            validatedBy: cleanedValidatedBy.isEmpty ? "Chef de Projet" : cleanedValidatedBy,
            activitySnapshots: projectActivities.map(PlanningBaselineActivitySnapshot.init(from:))
        )

        projects[projectIndex].planningBaselines.append(baseline)
        projects[projectIndex].planningBaselines.sort { $0.createdAt < $1.createdAt }
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
        return "Baseline planning \"\(baseline.label)\" enregistrée."
    }

    func planningVarianceReport(projectID: UUID) -> ProjectPlanningVarianceReport? {
        guard let project = project(with: projectID),
              let baseline = project.planningBaselines.last
        else {
            return nil
        }

        let currentActivities = Dictionary(uniqueKeysWithValues: activities(for: projectID).map { ($0.id, $0) })
        let variances = baseline.activitySnapshots.compactMap { snapshot -> PlanningActivityVariance? in
            guard let current = currentActivities[snapshot.id] else { return nil }
            let plannedEndDate = snapshot.estimatedEndDate
            let currentEndDate = current.estimatedEndDate
            let variance = Calendar.current.dateComponents([.day], from: plannedEndDate, to: currentEndDate).day ?? 0
            return PlanningActivityVariance(
                activityID: snapshot.id,
                title: current.displayTitle,
                plannedEndDate: plannedEndDate,
                currentEndDate: currentEndDate,
                varianceDays: variance,
                isMilestone: current.isMilestone
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return ProjectPlanningVarianceReport(
            baselineLabel: baseline.label,
            activityVariances: variances
        )
    }

    func deleteActivity(activityID: UUID) {
        activities.removeAll { $0.id == activityID }
        actions = actions.map { action in
            var updated = action
            if updated.activityID == activityID {
                updated.activityID = nil
                updated.updatedAt = .now
            }
            return updated
        }
        actions = sortActions(actions)
        persist()
    }

    func meetings(matching query: String) -> [ProjectMeeting] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return meetings }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalizedToken)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return meetings }

        return meetings.filter { meeting in
            let searchableValues = meetingSearchableValues(for: meeting).map(normalizedToken)
            return terms.allSatisfy { term in
                searchableValues.contains(where: { $0.contains(term) })
            }
        }
    }

    func addMeeting(
        title: String,
        projectID: UUID?,
        meetingAt: Date,
        durationMinutes: Int,
        mode: MeetingMode,
        organizer: String,
        participants: String,
        locationOrLink: String,
        notes: String,
        transcript: String,
        aiSummary: String
    ) -> UUID {
        let meeting = ProjectMeeting(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            projectID: sanitizedProjectID(projectID),
            meetingAt: meetingAt,
            durationMinutes: max(durationMinutes, 1),
            mode: mode,
            organizer: organizer.trimmingCharacters(in: .whitespacesAndNewlines),
            participants: participants.trimmingCharacters(in: .whitespacesAndNewlines),
            locationOrLink: locationOrLink.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            aiSummary: aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        meetings.append(meeting)
        meetings = sortMeetings(meetings)
        persist()
        return meeting.id
    }

    func updateMeeting(
        meetingID: UUID,
        title: String,
        projectID: UUID?,
        meetingAt: Date,
        durationMinutes: Int,
        mode: MeetingMode,
        organizer: String,
        participants: String,
        locationOrLink: String,
        notes: String,
        transcript: String,
        aiSummary: String
    ) {
        guard let index = meetings.firstIndex(where: { $0.id == meetingID }) else { return }
        meetings[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].projectID = sanitizedProjectID(projectID)
        meetings[index].meetingAt = meetingAt
        meetings[index].durationMinutes = max(durationMinutes, 1)
        meetings[index].mode = mode
        meetings[index].organizer = organizer.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].participants = participants.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].locationOrLink = locationOrLink.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].aiSummary = aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        meetings[index].updatedAt = .now
        meetings = sortMeetings(meetings)
        persist()
    }

    func deleteMeeting(meetingID: UUID) {
        meetings.removeAll { $0.id == meetingID }
        decisions = decisions.map { decision in
            var updatedDecision = decision
            updatedDecision.meetingIDs.removeAll { $0 == meetingID }
            return updatedDecision
        }
        persist()
    }

    func decisions(matching query: String) -> [ProjectDecision] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return decisions }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalizedToken)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return decisions }

        return decisions.filter { decision in
            let searchableValues = decisionSearchableValues(for: decision).map(normalizedToken)
            return terms.allSatisfy { term in
                searchableValues.contains(where: { $0.contains(term) })
            }
        }
    }

    func addDecision(
        title: String,
        details: String,
        status: DecisionStatus,
        projectID: UUID?,
        meetingIDs: [UUID],
        eventIDs: [UUID],
        impactedResourceIDs: [UUID]
    ) -> UUID {
        let now = Date.now
        let decisionID = UUID()
        let sequence = nextDecisionSequenceNumber()
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        let initialHistory = DecisionHistoryEntry(
            revision: 1,
            summary: "Création de la décision",
            status: status,
            snapshotTitle: cleanedTitle,
            snapshotDetails: cleanedDetails,
            recordedAt: now
        )

        let decision = ProjectDecision(
            id: decisionID,
            sequenceNumber: sequence,
            title: cleanedTitle,
            details: cleanedDetails,
            status: status,
            projectID: sanitizedProjectID(projectID),
            meetingIDs: sanitizedMeetingIDs(meetingIDs),
            eventIDs: sanitizedEventIDs(eventIDs),
            impactedResourceIDs: sanitizedResourceIDs(impactedResourceIDs),
            history: [initialHistory],
            comments: [],
            createdAt: now,
            updatedAt: now
        )

        decisions.append(decision)
        decisions = sortDecisions(decisions)
        persist()
        return decisionID
    }

    func updateDecision(
        decisionID: UUID,
        title: String,
        details: String,
        status: DecisionStatus,
        projectID: UUID?,
        meetingIDs: [UUID],
        eventIDs: [UUID],
        impactedResourceIDs: [UUID],
        changeSummary: String
    ) {
        guard let index = decisions.firstIndex(where: { $0.id == decisionID }) else { return }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSummary = changeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date.now

        decisions[index].title = cleanedTitle
        decisions[index].details = cleanedDetails
        decisions[index].status = status
        decisions[index].projectID = sanitizedProjectID(projectID)
        decisions[index].meetingIDs = sanitizedMeetingIDs(meetingIDs)
        decisions[index].eventIDs = sanitizedEventIDs(eventIDs)
        decisions[index].impactedResourceIDs = sanitizedResourceIDs(impactedResourceIDs)
        decisions[index].updatedAt = now

        let nextRevision = (decisions[index].history.map(\.revision).max() ?? 0) + 1
        decisions[index].history.append(
            DecisionHistoryEntry(
                revision: nextRevision,
                summary: normalizedSummary.isEmpty ? "Mise à jour de la décision" : normalizedSummary,
                status: status,
                snapshotTitle: cleanedTitle,
                snapshotDetails: cleanedDetails,
                recordedAt: now
            )
        )
        decisions[index].history.sort { $0.recordedAt < $1.recordedAt }

        decisions = sortDecisions(decisions)
        persist()
    }

    func deleteDecision(decisionID: UUID) {
        decisions.removeAll { $0.id == decisionID }
        persist()
    }

    func addDecisionComment(decisionID: UUID, author: String, body: String) {
        guard let index = decisions.firstIndex(where: { $0.id == decisionID }) else { return }
        let cleanedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedBody.isEmpty == false else { return }

        let comment = DecisionComment(
            author: cleanedAuthor.isEmpty ? "Anonyme" : cleanedAuthor,
            body: cleanedBody
        )
        decisions[index].comments.append(comment)
        decisions[index].comments.sort { $0.createdAt < $1.createdAt }
        decisions[index].updatedAt = .now
        decisions = sortDecisions(decisions)
        persist()
    }

    func projectName(for id: UUID?) -> String {
        guard let id else { return "Sans projet" }
        return project(with: id)?.name ?? "Projet supprimé"
    }

    func resourceNames(for ids: [UUID]) -> [String] {
        let namesByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0.displayName) })
        return ids.compactMap { namesByID[$0] }
    }

    func addProject(
        name: String,
        summary: String,
        sponsor: String,
        manager: String,
        phase: ProjectPhase,
        health: ProjectHealth,
        deliveryMode: DeliveryMode,
        startDate: Date,
        targetDate: Date
    ) -> UUID {
        let project = Project(
            name: name,
            summary: summary,
            sponsor: sponsor,
            manager: manager,
            phase: phase,
            health: health,
            deliveryMode: deliveryMode,
            startDate: startDate,
            targetDate: targetDate
        )

        projects.append(project)
        projects = sortProjects(projects)
        persist()
        return project.id
    }

    func updateProjectQuick(
        projectID: UUID,
        name: String,
        health: ProjectHealth
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        projects[index].name = cleanedName.isEmpty ? projects[index].name : cleanedName
        projects[index].health = health
        projects[index].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func replaceProjectTestingPhase(projectID: UUID, phase: ProjectTestingPhase) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }

        var phases = ProjectTestingPhase.normalizedPhases(projects[projectIndex].testingPhases)
        if let phaseIndex = phases.firstIndex(where: { $0.kind == phase.kind }) {
            phases[phaseIndex] = phase
        } else {
            phases.append(phase)
        }

        projects[projectIndex].testingPhases = ProjectTestingPhase.normalizedPhases(phases)
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func shouldSuggestGoNoGoDecision(projectID: UUID) -> Bool {
        guard let project = project(with: projectID) else { return false }
        return project.isUATCompletedForGoNoGo && hasGoNoGoDecision(projectID: projectID) == false
    }

    @discardableResult
    func createGoNoGoDecision(projectID: UUID) -> UUID? {
        guard let project = project(with: projectID) else { return nil }
        guard shouldSuggestGoNoGoDecision(projectID: projectID) else { return nil }

        let details = """
        Déclenchée automatiquement par le module Tests:
        - UAT à 100%
        - Validation attendue pour la mise en production

        Merci de statuer Go / No-Go et de documenter les conditions éventuelles.
        """

        return addDecision(
            title: "Go / No-Go — \(project.name)",
            details: details,
            status: .proposedUnderReview,
            projectID: projectID,
            meetingIDs: [],
            eventIDs: [],
            impactedResourceIDs: []
        )
    }

    func addRisk(
        to projectID: UUID,
        title: String,
        mitigation: String,
        owner: String,
        severity: RiskSeverity,
        dueDate: Date?
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        let risk = Risk(
            title: title,
            mitigation: mitigation,
            owner: owner,
            severity: severity,
            dueDate: dueDate,
            projectNames: projects[index].name,
            assignedTo: owner,
            riskTitle: title,
            counterMeasure: mitigation
        )

        projects[index].risks.append(risk)
        projects[index].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func updateRiskQuick(
        riskID: UUID,
        title: String,
        owner: String,
        severity: RiskSeverity,
        status: String
    ) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)

        for projectIndex in projects.indices {
            guard let riskIndex = projects[projectIndex].risks.firstIndex(where: { $0.id == riskID }) else { continue }

            if cleanedTitle.isEmpty == false {
                projects[projectIndex].risks[riskIndex].title = cleanedTitle
                projects[projectIndex].risks[riskIndex].riskTitle = cleanedTitle
            }
            if cleanedOwner.isEmpty == false {
                projects[projectIndex].risks[riskIndex].owner = cleanedOwner
                projects[projectIndex].risks[riskIndex].assignedTo = cleanedOwner
            }
            projects[projectIndex].risks[riskIndex].severity = severity
            projects[projectIndex].risks[riskIndex].riskStatus = cleanedStatus
            projects[projectIndex].risks[riskIndex].lastModifiedAt = .now
            projects[projectIndex].updatedAt = .now

            projects = sortProjects(projects)
            persist()
            return
        }

        guard let riskIndex = unassignedRisks.firstIndex(where: { $0.id == riskID }) else { return }

        if cleanedTitle.isEmpty == false {
            unassignedRisks[riskIndex].title = cleanedTitle
            unassignedRisks[riskIndex].riskTitle = cleanedTitle
        }
        if cleanedOwner.isEmpty == false {
            unassignedRisks[riskIndex].owner = cleanedOwner
            unassignedRisks[riskIndex].assignedTo = cleanedOwner
        }
        unassignedRisks[riskIndex].severity = severity
        unassignedRisks[riskIndex].riskStatus = cleanedStatus
        unassignedRisks[riskIndex].lastModifiedAt = .now
        unassignedRisks = sortStandaloneRisks(unassignedRisks)
        persist()
    }

    func importRisks(_ drafts: [RiskImportDraft]) -> RiskImportResult {
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        var firstImportedOrUpdatedRiskID: UUID?

        for draft in drafts {
            let normalized = normalizedRiskFields(from: draft)
            guard normalized.displayTitle.isEmpty == false else {
                skippedCount += 1
                continue
            }

            let matchingKey = riskMatchingKey(externalID: normalized.externalID, title: normalized.displayTitle)

            if let existing = findRiskLocation(by: matchingKey) {
                switch existing {
                case .project(let projectIndex, let riskIndex):
                    projects[projectIndex].risks[riskIndex] = normalized.risk
                    projects[projectIndex].updatedAt = .now
                    updatedCount += 1
                    if firstImportedOrUpdatedRiskID == nil { firstImportedOrUpdatedRiskID = normalized.risk.id }
                case .unassigned(let riskIndex):
                    unassignedRisks[riskIndex] = normalized.risk
                    updatedCount += 1
                    if firstImportedOrUpdatedRiskID == nil { firstImportedOrUpdatedRiskID = normalized.risk.id }
                }
                continue
            }

            if let projectID = resolveProjectID(from: normalized.risk.projectNames),
               let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
                projects[projectIndex].risks.append(normalized.risk)
                projects[projectIndex].updatedAt = .now
            } else {
                unassignedRisks.append(normalized.risk)
            }

            importedCount += 1
            if firstImportedOrUpdatedRiskID == nil { firstImportedOrUpdatedRiskID = normalized.risk.id }
        }

        unassignedRisks = sortStandaloneRisks(unassignedRisks)
        projects = sortProjects(projects)
        persist()

        return RiskImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount,
            firstImportedOrUpdatedRiskID: firstImportedOrUpdatedRiskID
        )
    }

    func addDeliverable(
        to projectID: UUID,
        title: String,
        details: String,
        owner: String,
        dueDate: Date,
        phase: DeliverablePhase = .delivery,
        parentDeliverableID: UUID? = nil,
        isMilestone: Bool = false,
        acceptanceCriteria: [String] = [],
        integratedSourceProjectID: UUID? = nil
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        let deliverable = Deliverable(
            title: title,
            details: details,
            owner: owner,
            dueDate: dueDate,
            phase: phase,
            parentDeliverableID: parentDeliverableID,
            isMilestone: isMilestone,
            acceptanceCriteria: normalizedAcceptanceCriteria(acceptanceCriteria),
            integratedSourceProjectID: integratedSourceProjectID
        )

        projects[index].deliverables.append(deliverable)
        projects[index].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func updateProjectScope(
        projectID: UUID,
        inScopeItems: [String],
        outOfScopeItems: [String],
        linkedAnnexProjectIDs: [UUID]
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let validLinkedProjectIDs = linkedAnnexProjectIDs
            .filter { linkedID in
                linkedID != projectID && projects.contains(where: { $0.id == linkedID })
            }
            .reduce(into: [UUID]()) { partial, value in
                if partial.contains(value) == false {
                    partial.append(value)
                }
            }

        projects[projectIndex].scopeDefinition = ProjectScopeDefinition(
            inScopeItems: normalizedScopeItems(inScopeItems),
            outOfScopeItems: normalizedScopeItems(outOfScopeItems),
            linkedAnnexProjectIDs: validLinkedProjectIDs
        )
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func createScopeBaseline(
        projectID: UUID,
        milestoneLabel: String,
        validatedBy: String
    ) -> String? {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return nil }

        let cleanedMilestoneLabel = milestoneLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedValidatedBy = validatedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopeSnapshot = projects[projectIndex].scopeDefinition ?? ProjectScopeDefinition()

        let associableChangeRequestIDs = projects[projectIndex].scopeChangeRequests
            .filter {
                $0.associatedBaselineID == nil && ($0.status == .reviewed || $0.status == .approved || $0.status == .rejected)
            }
            .map(\.id)

        let baseline = ScopeBaseline(
            milestoneLabel: cleanedMilestoneLabel.isEmpty ? "Milestone" : cleanedMilestoneLabel,
            validatedBy: cleanedValidatedBy.isEmpty ? "Chef de Projet" : cleanedValidatedBy,
            scopeSnapshot: scopeSnapshot,
            deliverableSnapshots: projects[projectIndex].deliverables,
            associatedChangeRequestIDs: associableChangeRequestIDs
        )

        projects[projectIndex].scopeBaselines.append(baseline)
        projects[projectIndex].scopeBaselines.sort { $0.createdAt < $1.createdAt }

        for requestIndex in projects[projectIndex].scopeChangeRequests.indices {
            if associableChangeRequestIDs.contains(projects[projectIndex].scopeChangeRequests[requestIndex].id) {
                projects[projectIndex].scopeChangeRequests[requestIndex].associatedBaselineID = baseline.id
                projects[projectIndex].scopeChangeRequests[requestIndex].updatedAt = .now
            }
        }

        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
        return "Baseline \"\(baseline.milestoneLabel)\" validée."
    }

    func submitScopeChangeRequest(
        projectID: UUID,
        description: String,
        impactPlanning: String,
        impactResources: String,
        impactRisks: String,
        requestedBy: String
    ) -> String? {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return nil }

        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPlanning = impactPlanning.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedResources = impactResources.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRisks = impactRisks.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRequestedBy = requestedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedDescription.isEmpty == false else { return nil }

        let request = ScopeChangeRequest(
            description: cleanedDescription,
            impactPlanning: cleanedPlanning,
            impactResources: cleanedResources,
            impactRisks: cleanedRisks,
            status: .proposed,
            requestedBy: cleanedRequestedBy.isEmpty ? "Chef de Projet" : cleanedRequestedBy,
            history: [
                ScopeChangeRequestHistoryEntry(
                    status: .proposed,
                    actor: cleanedRequestedBy.isEmpty ? "Chef de Projet" : cleanedRequestedBy,
                    note: "Demande créée"
                )
            ]
        )

        projects[projectIndex].scopeChangeRequests.append(request)
        projects[projectIndex].scopeChangeRequests.sort { $0.createdAt < $1.createdAt }
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
        return "Change Request créée au statut Proposed."
    }

    func transitionScopeChangeRequest(
        projectID: UUID,
        requestID: UUID,
        targetStatus: ScopeChangeRequestStatus,
        actor: String,
        note: String
    ) -> String? {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let requestIndex = projects[projectIndex].scopeChangeRequests.firstIndex(where: { $0.id == requestID })
        else {
            return nil
        }

        let currentStatus = projects[projectIndex].scopeChangeRequests[requestIndex].status
        let transitionAllowed: Bool = {
            switch (currentStatus, targetStatus) {
            case (.proposed, .reviewed):
                true
            case (.reviewed, .approved), (.reviewed, .rejected):
                true
            default:
                false
            }
        }()

        guard transitionAllowed else { return nil }

        let cleanedActor = actor.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        projects[projectIndex].scopeChangeRequests[requestIndex].status = targetStatus
        projects[projectIndex].scopeChangeRequests[requestIndex].updatedAt = .now
        projects[projectIndex].scopeChangeRequests[requestIndex].history.append(
            ScopeChangeRequestHistoryEntry(
                status: targetStatus,
                actor: cleanedActor.isEmpty ? "Chef de Projet" : cleanedActor,
                note: cleanedNote
            )
        )
        projects[projectIndex].scopeChangeRequests[requestIndex].history.sort { $0.changedAt < $1.changedAt }

        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
        return "Change Request passée à \(targetStatus.label)."
    }

    func addAcceptanceCriterion(projectID: UUID, deliverableID: UUID, criterionText: String) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let deliverableIndex = projects[projectIndex].deliverables.firstIndex(where: { $0.id == deliverableID })
        else {
            return
        }

        let cleanedText = criterionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedText.isEmpty == false else { return }

        projects[projectIndex].deliverables[deliverableIndex].acceptanceCriteria.append(
            DeliverableAcceptanceCriterion(text: cleanedText)
        )
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func toggleAcceptanceCriterion(projectID: UUID, deliverableID: UUID, criterionID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let deliverableIndex = projects[projectIndex].deliverables.firstIndex(where: { $0.id == deliverableID }),
              let criterionIndex = projects[projectIndex].deliverables[deliverableIndex].acceptanceCriteria.firstIndex(where: { $0.id == criterionID })
        else {
            return
        }

        projects[projectIndex].deliverables[deliverableIndex].acceptanceCriteria[criterionIndex].isValidated.toggle()
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func removeAcceptanceCriterion(projectID: UUID, deliverableID: UUID, criterionID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let deliverableIndex = projects[projectIndex].deliverables.firstIndex(where: { $0.id == deliverableID })
        else {
            return
        }

        projects[projectIndex].deliverables[deliverableIndex].acceptanceCriteria.removeAll { $0.id == criterionID }
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func annexDeliverablesIntegrated(into primaryProjectID: UUID) -> [DeliverableEntry] {
        guard let primaryProject = project(with: primaryProjectID),
              let scopeDefinition = primaryProject.scopeDefinition
        else {
            return []
        }

        let linkedProjectIDs = Set(scopeDefinition.linkedAnnexProjectIDs)
        return deliverables
            .filter { entry in
                linkedProjectIDs.contains(entry.projectID)
            }
    }

    func updateDeliverableQuick(
        projectID: UUID,
        deliverableID: UUID,
        title: String,
        owner: String
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let deliverableIndex = projects[projectIndex].deliverables.firstIndex(where: { $0.id == deliverableID })
        else {
            return
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)

        projects[projectIndex].deliverables[deliverableIndex].title = cleanedTitle.isEmpty ? projects[projectIndex].deliverables[deliverableIndex].title : cleanedTitle
        projects[projectIndex].deliverables[deliverableIndex].owner = cleanedOwner.isEmpty ? projects[projectIndex].deliverables[deliverableIndex].owner : cleanedOwner
        projects[projectIndex].updatedAt = .now
        projects = sortProjects(projects)
        persist()
    }

    func toggleDeliverable(projectID: UUID, deliverableID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let deliverableIndex = projects[projectIndex].deliverables.firstIndex(where: { $0.id == deliverableID })
        else {
            return
        }

        projects[projectIndex].deliverables[deliverableIndex].isDone.toggle()
        projects[projectIndex].updatedAt = .now
        persist()
    }

    func addResource(
        nom: String,
        parentDescription: String?,
        primaryResourceRole: String?,
        resourceRoles: String?,
        organizationalResource: String?,
        competence1: String?,
        resourceCalendar: String?,
        resourceStartDate: Date?,
        resourceFinishDate: Date?,
        responsableOperationnel: String?,
        responsableInterne: String?,
        localisation: String?,
        typeDeRessource: String?,
        journeesTempsPartiel: String?,
        email: String,
        phone: String,
        assignedProjectIDs: [UUID],
        notes: String
    ) -> UUID {
        let normalized = normalizedResourceFields(
            nom: nom,
            parentDescription: parentDescription,
            primaryResourceRole: primaryResourceRole,
            resourceRoles: resourceRoles,
            organizationalResource: organizationalResource,
            competence1: competence1,
            resourceCalendar: resourceCalendar,
            resourceStartDate: resourceStartDate,
            resourceFinishDate: resourceFinishDate,
            responsableOperationnel: responsableOperationnel,
            responsableInterne: responsableInterne,
            localisation: localisation,
            typeDeRessource: typeDeRessource,
            journeesTempsPartiel: journeesTempsPartiel
        )

        let resource = Resource(
            fullName: normalized.fullName,
            jobTitle: normalized.jobTitle,
            department: normalized.department,
            nom: normalized.nom,
            parentDescription: normalized.parentDescription,
            primaryResourceRole: normalized.primaryResourceRole,
            resourceRoles: normalized.resourceRoles,
            organizationalResource: normalized.organizationalResource,
            competence1: normalized.competence1,
            resourceCalendar: normalized.resourceCalendar,
            resourceStartDate: normalized.resourceStartDate,
            resourceFinishDate: normalized.resourceFinishDate,
            responsableOperationnel: normalized.responsableOperationnel,
            responsableInterne: normalized.responsableInterne,
            localisation: normalized.localisation,
            typeDeRessource: normalized.typeDeRessource,
            journeesTempsPartiel: normalized.journeesTempsPartiel,
            email: email,
            phone: phone,
            engagement: normalized.engagement,
            status: normalized.status,
            allocationPercent: normalized.allocationPercent,
            assignedProjectIDs: assignedProjectIDs,
            notes: notes
        )

        resources.append(resource)
        resources = sortResources(resources)
        persist()
        return resource.id
    }

    func updateResource(
        resourceID: UUID,
        nom: String,
        parentDescription: String?,
        primaryResourceRole: String?,
        resourceRoles: String?,
        organizationalResource: String?,
        competence1: String?,
        resourceCalendar: String?,
        resourceStartDate: Date?,
        resourceFinishDate: Date?,
        responsableOperationnel: String?,
        responsableInterne: String?,
        localisation: String?,
        typeDeRessource: String?,
        journeesTempsPartiel: String?,
        email: String,
        phone: String,
        assignedProjectIDs: [UUID],
        notes: String
    ) {
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return }

        let normalized = normalizedResourceFields(
            nom: nom,
            parentDescription: parentDescription,
            primaryResourceRole: primaryResourceRole,
            resourceRoles: resourceRoles,
            organizationalResource: organizationalResource,
            competence1: competence1,
            resourceCalendar: resourceCalendar,
            resourceStartDate: resourceStartDate,
            resourceFinishDate: resourceFinishDate,
            responsableOperationnel: responsableOperationnel,
            responsableInterne: responsableInterne,
            localisation: localisation,
            typeDeRessource: typeDeRessource,
            journeesTempsPartiel: journeesTempsPartiel
        )

        resources[index].fullName = normalized.fullName
        resources[index].jobTitle = normalized.jobTitle
        resources[index].department = normalized.department
        resources[index].nom = normalized.nom
        resources[index].parentDescription = normalized.parentDescription
        resources[index].primaryResourceRole = normalized.primaryResourceRole
        resources[index].resourceRoles = normalized.resourceRoles
        resources[index].organizationalResource = normalized.organizationalResource
        resources[index].competence1 = normalized.competence1
        resources[index].resourceCalendar = normalized.resourceCalendar
        resources[index].resourceStartDate = normalized.resourceStartDate
        resources[index].resourceFinishDate = normalized.resourceFinishDate
        resources[index].responsableOperationnel = normalized.responsableOperationnel
        resources[index].responsableInterne = normalized.responsableInterne
        resources[index].localisation = normalized.localisation
        resources[index].typeDeRessource = normalized.typeDeRessource
        resources[index].journeesTempsPartiel = normalized.journeesTempsPartiel
        resources[index].email = email
        resources[index].phone = phone
        resources[index].engagement = normalized.engagement
        resources[index].status = normalized.status
        resources[index].allocationPercent = normalized.allocationPercent
        resources[index].assignedProjectIDs = assignedProjectIDs
        resources[index].notes = notes
        resources[index].updatedAt = .now
        resources = sortResources(resources)
        persist()
    }

    func updateResourceQuick(
        resourceID: UUID,
        nom: String,
        parentDescription: String,
        primaryResourceRole: String,
        email: String,
        phone: String,
        allocationPercent: Int,
        status: ResourceStatus,
        engagement: ResourceEngagement
    ) {
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return }

        let cleanedNom = cleanedOptionalString(nom) ?? resources[index].fullName
        let cleanedParentDescription = cleanedOptionalString(parentDescription)
        let cleanedPrimaryRole = cleanedOptionalString(primaryResourceRole)

        resources[index].fullName = cleanedNom
        resources[index].nom = cleanedNom

        if let cleanedParentDescription {
            resources[index].parentDescription = cleanedParentDescription
            resources[index].department = cleanedParentDescription
        }

        if let cleanedPrimaryRole {
            resources[index].primaryResourceRole = cleanedPrimaryRole
            resources[index].jobTitle = cleanedPrimaryRole
        }

        resources[index].email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        resources[index].phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        resources[index].allocationPercent = min(max(allocationPercent, 0), 100)
        resources[index].status = status
        resources[index].engagement = engagement
        resources[index].updatedAt = .now

        resources = sortResources(resources)
        persist()
    }

    func deleteResource(resourceID: UUID) {
        resources.removeAll { $0.id == resourceID }
        decisions = decisions.map { decision in
            var updatedDecision = decision
            updatedDecision.impactedResourceIDs.removeAll { $0 == resourceID }
            return updatedDecision
        }
        persist()
    }

    func importResources(_ drafts: [ResourceImportDraft]) -> ResourceImportResult {
        let reviewItems = prepareResourceImportReview(drafts)
        let decisions = reviewItems.map {
            ResourceImportDecision(reviewItemID: $0.id, shouldApply: $0.action == .create || $0.action == .update)
        }
        return applyResourceImportReview(reviewItems, decisions: decisions)
    }

    func prepareResourceImportReview(_ drafts: [ResourceImportDraft]) -> [ResourceImportReviewItem] {
        var reviewItems: [ResourceImportReviewItem] = []

        for draft in drafts {
            let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedResourceFields(
                nom: draft.nom,
                parentDescription: draft.parentDescription,
                primaryResourceRole: draft.primaryResourceRole,
                resourceRoles: draft.resourceRoles,
                organizationalResource: draft.organizationalResource,
                competence1: draft.competence1,
                resourceCalendar: draft.resourceCalendar,
                resourceStartDate: draft.resourceStartDate,
                resourceFinishDate: draft.resourceFinishDate,
                responsableOperationnel: draft.responsableOperationnel,
                responsableInterne: draft.responsableInterne,
                localisation: draft.localisation,
                typeDeRessource: draft.typeDeRessource,
                journeesTempsPartiel: draft.journeesTempsPartiel
            )

            guard normalized.fullName.isEmpty == false else {
                reviewItems.append(
                    ResourceImportReviewItem(
                        sourceRowNumber: draft.sourceRowNumber,
                        action: .skipped,
                        resourceID: nil,
                        displayName: "(ligne sans nom)",
                        changes: [],
                        proposedResource: nil,
                        isExistingResource: false
                    )
                )
                continue
            }

            let normalizedKey = resourceMatchingKey(fullName: normalized.fullName, jobTitle: normalized.jobTitle)

            if let index = resources.firstIndex(where: {
                resourceMatchingKey(fullName: $0.fullName, jobTitle: $0.jobTitle) == normalizedKey
            }) {
                let existingResource = resources[index]
                let updateResult = mergeExistingResource(
                    existingResource,
                    draft: draft,
                    normalized: normalized,
                    trimmedNotes: trimmedNotes
                )

                reviewItems.append(
                    ResourceImportReviewItem(
                        sourceRowNumber: draft.sourceRowNumber,
                        action: updateResult.changes.isEmpty ? .noChange : .update,
                        resourceID: existingResource.id,
                        displayName: existingResource.displayName,
                        changes: updateResult.changes,
                        proposedResource: updateResult.mergedResource,
                        isExistingResource: true
                    )
                )
            } else {
                let createdResource = Resource(
                    fullName: normalized.fullName,
                    jobTitle: normalized.jobTitle,
                    department: normalized.department,
                    nom: normalized.nom,
                    parentDescription: normalized.parentDescription,
                    primaryResourceRole: normalized.primaryResourceRole,
                    resourceRoles: normalized.resourceRoles,
                    organizationalResource: normalized.organizationalResource,
                    competence1: normalized.competence1,
                    resourceCalendar: normalized.resourceCalendar,
                    resourceStartDate: normalized.resourceStartDate,
                    resourceFinishDate: normalized.resourceFinishDate,
                    responsableOperationnel: normalized.responsableOperationnel,
                    responsableInterne: normalized.responsableInterne,
                    localisation: normalized.localisation,
                    typeDeRessource: normalized.typeDeRessource,
                    journeesTempsPartiel: normalized.journeesTempsPartiel,
                    email: "",
                    phone: "",
                    engagement: normalized.engagement,
                    status: normalized.status,
                    allocationPercent: normalized.allocationPercent,
                    assignedProjectIDs: [],
                    notes: trimmedNotes
                )

                reviewItems.append(
                    ResourceImportReviewItem(
                        sourceRowNumber: draft.sourceRowNumber,
                        action: .create,
                        resourceID: createdResource.id,
                        displayName: createdResource.displayName,
                        changes: creationFieldChanges(for: createdResource),
                        proposedResource: createdResource,
                        isExistingResource: false
                    )
                )
            }
        }

        return reviewItems.sorted { $0.sourceRowNumber < $1.sourceRowNumber }
    }

    func applyResourceImportReview(_ reviewItems: [ResourceImportReviewItem], decisions: [ResourceImportDecision]) -> ResourceImportResult {
        let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.reviewItemID, $0.shouldApply) })
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        var firstImportedOrUpdatedResourceID: UUID?

        for item in reviewItems {
            let shouldApply = decisionsByID[item.id] ?? false

            switch item.action {
            case .create:
                guard shouldApply, let createdResource = item.proposedResource else {
                    skippedCount += 1
                    continue
                }

                resources.append(createdResource)
                importedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = createdResource.id
                }
            case .update:
                guard shouldApply, let updatedResource = item.proposedResource else {
                    skippedCount += 1
                    continue
                }

                guard let index = resources.firstIndex(where: { $0.id == updatedResource.id }) else {
                    skippedCount += 1
                    continue
                }

                resources[index] = updatedResource
                updatedCount += 1
                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = updatedResource.id
                }
            case .noChange, .skipped:
                skippedCount += 1
            }
        }

        resources = sortResources(resources)
        persist()

        return ResourceImportResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount,
            firstImportedOrUpdatedResourceID: firstImportedOrUpdatedResourceID
        )
    }

    private struct MergeExistingResourceResult {
        let mergedResource: Resource
        let changes: [ResourceImportFieldChange]
    }

    private func mergeExistingResource(
        _ existingResource: Resource,
        draft: ResourceImportDraft,
        normalized: NormalizedResourceFields,
        trimmedNotes: String
    ) -> MergeExistingResourceResult {
        var merged = existingResource
        var changes: [ResourceImportFieldChange] = []

        func applyStringValue(_ newValue: String?, label: String, keyPath: WritableKeyPath<Resource, String>) {
            guard let newValue else { return }
            let currentValue = merged[keyPath: keyPath]
            guard currentValue != newValue else { return }
            changes.append(ResourceImportFieldChange(fieldLabel: label, oldValue: currentValue, newValue: newValue))
            merged[keyPath: keyPath] = newValue
        }

        func applyOptionalStringValue(_ newValue: String?, label: String, keyPath: WritableKeyPath<Resource, String?>) {
            guard let newValue else { return }
            let currentValue = merged[keyPath: keyPath]
            guard currentValue != newValue else { return }
            changes.append(ResourceImportFieldChange(fieldLabel: label, oldValue: currentValue ?? "-", newValue: newValue))
            merged[keyPath: keyPath] = newValue
        }

        func applyOptionalDateValue(_ newValue: Date?, label: String, keyPath: WritableKeyPath<Resource, Date?>) {
            guard let newValue else { return }
            let currentValue = merged[keyPath: keyPath]
            guard currentValue != newValue else { return }
            changes.append(
                ResourceImportFieldChange(
                    fieldLabel: label,
                    oldValue: currentValue?.formatted(date: .abbreviated, time: .omitted) ?? "-",
                    newValue: newValue.formatted(date: .abbreviated, time: .omitted)
                )
            )
            merged[keyPath: keyPath] = newValue
        }

        applyStringValue(normalized.fullName.isEmpty ? nil : normalized.fullName, label: "Nom", keyPath: \.fullName)
        applyStringValue(normalized.jobTitle.isEmpty ? nil : normalized.jobTitle, label: "Job Title", keyPath: \.jobTitle)
        applyStringValue(normalized.department.isEmpty ? nil : normalized.department, label: "Département", keyPath: \.department)
        applyOptionalStringValue(normalized.nom, label: "Nom (source)", keyPath: \.nom)
        applyOptionalStringValue(normalized.parentDescription, label: "Parent Description", keyPath: \.parentDescription)
        applyOptionalStringValue(normalized.primaryResourceRole, label: "Primary Resource Role", keyPath: \.primaryResourceRole)
        applyOptionalStringValue(normalized.resourceRoles, label: "Resource Roles", keyPath: \.resourceRoles)
        applyOptionalStringValue(normalized.organizationalResource, label: "Organizational Resource", keyPath: \.organizationalResource)
        applyOptionalStringValue(normalized.competence1, label: "Compétence 1", keyPath: \.competence1)
        applyOptionalStringValue(normalized.resourceCalendar, label: "Resource Calendar", keyPath: \.resourceCalendar)
        applyOptionalDateValue(normalized.resourceStartDate, label: "Resource Start Date", keyPath: \.resourceStartDate)
        applyOptionalDateValue(normalized.resourceFinishDate, label: "Resource Finish Date", keyPath: \.resourceFinishDate)
        applyOptionalStringValue(normalized.responsableOperationnel, label: "Responsable Opérationnel", keyPath: \.responsableOperationnel)
        applyOptionalStringValue(normalized.responsableInterne, label: "Responsable Interne", keyPath: \.responsableInterne)
        applyOptionalStringValue(normalized.localisation, label: "Localisation", keyPath: \.localisation)
        applyOptionalStringValue(normalized.typeDeRessource, label: "Type de Ressource", keyPath: \.typeDeRessource)
        applyOptionalStringValue(normalized.journeesTempsPartiel, label: "Journée(s) temps partiel", keyPath: \.journeesTempsPartiel)

        if draft.typeDeRessource?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           merged.engagement != normalized.engagement {
            changes.append(
                ResourceImportFieldChange(
                    fieldLabel: "Engagement",
                    oldValue: merged.engagement.label,
                    newValue: normalized.engagement.label
                )
            )
            merged.engagement = normalized.engagement
        }

        let hasPartTimeDays = draft.journeesTempsPartiel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasFinishDate = draft.resourceFinishDate != nil

        if hasPartTimeDays, merged.allocationPercent != normalized.allocationPercent {
            changes.append(
                ResourceImportFieldChange(
                    fieldLabel: "Allocation (%)",
                    oldValue: "\(merged.allocationPercent)",
                    newValue: "\(normalized.allocationPercent)"
                )
            )
            merged.allocationPercent = normalized.allocationPercent
        }

        if hasPartTimeDays || hasFinishDate {
            if merged.status != normalized.status {
                changes.append(
                    ResourceImportFieldChange(
                        fieldLabel: "Statut",
                        oldValue: merged.status.label,
                        newValue: normalized.status.label
                    )
                )
                merged.status = normalized.status
            }
        }

        if trimmedNotes.isEmpty == false, merged.notes != trimmedNotes {
            changes.append(
                ResourceImportFieldChange(
                    fieldLabel: "Notes",
                    oldValue: merged.notes.isEmpty ? "-" : merged.notes,
                    newValue: trimmedNotes
                )
            )
            merged.notes = trimmedNotes
        }

        if changes.isEmpty == false {
            merged.updatedAt = .now
        }

        return MergeExistingResourceResult(mergedResource: merged, changes: changes)
    }

    private func creationFieldChanges(for resource: Resource) -> [ResourceImportFieldChange] {
        var changes: [ResourceImportFieldChange] = []

        func appendIfValue(_ value: String, label: String) {
            guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
            changes.append(ResourceImportFieldChange(fieldLabel: label, oldValue: "-", newValue: value))
        }

        appendIfValue(resource.displayName, label: "Nom")
        appendIfValue(resource.parentDescription ?? "", label: "Parent Description")
        appendIfValue(resource.primaryResourceRole ?? "", label: "Primary Resource Role")
        appendIfValue(resource.resourceRoles ?? "", label: "Resource Roles")
        appendIfValue(resource.organizationalResource ?? "", label: "Organizational Resource")
        appendIfValue(resource.competence1 ?? "", label: "Compétence 1")
        appendIfValue(resource.resourceCalendar ?? "", label: "Resource Calendar")
        appendIfValue(resource.resourceStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "", label: "Resource Start Date")
        appendIfValue(resource.resourceFinishDate?.formatted(date: .abbreviated, time: .omitted) ?? "", label: "Resource Finish Date")
        appendIfValue(resource.responsableOperationnel ?? "", label: "Responsable Opérationnel")
        appendIfValue(resource.responsableInterne ?? "", label: "Responsable Interne")
        appendIfValue(resource.localisation ?? "", label: "Localisation")
        appendIfValue(resource.typeDeRessource ?? "", label: "Type de Ressource")
        appendIfValue(resource.journeesTempsPartiel ?? "", label: "Journée(s) temps partiel")
        appendIfValue(resource.engagement.label, label: "Engagement")
        appendIfValue(resource.status.label, label: "Statut")
        appendIfValue("\(resource.allocationPercent)", label: "Allocation (%)")
        appendIfValue(resource.notes, label: "Notes")

        if changes.isEmpty {
            changes.append(ResourceImportFieldChange(fieldLabel: "Création", oldValue: "-", newValue: "Nouvelle ressource"))
        }

        return changes
    }

    private func persist() {
        let snapshot = makeDatabase()
        Task(priority: .utility) { [persistence] in
            do {
                try await persistence.save(snapshot)
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = "Sauvegarde impossible : \(error.localizedDescription)"
                }
            }
        }
    }

    private func sortProjects(_ projects: [Project]) -> [Project] {
        projects.sorted {
            if $0.targetDate == $1.targetDate {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.targetDate < $1.targetDate
        }
    }

    private func sortResources(_ resources: [Resource]) -> [Resource] {
        resources.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    private func sortActivities(_ activities: [ProjectActivity]) -> [ProjectActivity] {
        activities.sorted {
            if $0.estimatedEndDate == $1.estimatedEndDate {
                return $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
            }
            return $0.estimatedEndDate < $1.estimatedEndDate
        }
    }

    private func sortEvents(_ events: [ProjectEvent]) -> [ProjectEvent] {
        events.sorted {
            if $0.happenedAt == $1.happenedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.happenedAt > $1.happenedAt
        }
    }

    private func sortActions(_ actions: [ProjectAction]) -> [ProjectAction] {
        actions.sorted {
            if $0.isDone != $1.isDone {
                return $0.isDone == false
            }
            if $0.dueDate == $1.dueDate {
                if $0.priority.sortWeight == $1.priority.sortWeight {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.priority.sortWeight > $1.priority.sortWeight
            }
            return $0.dueDate < $1.dueDate
        }
    }

    private func sortMeetings(_ meetings: [ProjectMeeting]) -> [ProjectMeeting] {
        meetings.sorted {
            if $0.meetingAt == $1.meetingAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.meetingAt > $1.meetingAt
        }
    }

    private func sortDecisions(_ decisions: [ProjectDecision]) -> [ProjectDecision] {
        decisions.sorted {
            if $0.sequenceNumber == $1.sequenceNumber {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.sequenceNumber < $1.sequenceNumber
        }
    }

    private func sortGovernanceReports(_ reports: [GovernanceReportRecord]) -> [GovernanceReportRecord] {
        reports.sorted { lhs, rhs in
            if lhs.generatedReport.periodStart == rhs.generatedReport.periodStart {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.generatedReport.periodStart > rhs.generatedReport.periodStart
        }
    }

    private func validatedDatabase(from database: SamouraiDatabase) throws -> SamouraiDatabase {
        let projectIDs = database.projects.map(\.id)
        guard Set(projectIDs).count == projectIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs projets dupliqués.")
        }

        let resourceIDs = database.resources.map(\.id)
        guard Set(resourceIDs).count == resourceIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs ressources dupliqués.")
        }

        let projectRiskIDs = database.projects.flatMap(\.risks).map(\.id)
        let orphanRiskIDs = database.unassignedRisks.map(\.id)
        let allRiskIDs = projectRiskIDs + orphanRiskIDs
        guard Set(allRiskIDs).count == allRiskIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs risques dupliqués.")
        }

        let eventIDs = database.events.map(\.id)
        guard Set(eventIDs).count == eventIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs événements dupliqués.")
        }

        let actionIDs = database.actions.map(\.id)
        guard Set(actionIDs).count == actionIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs actions dupliqués.")
        }

        let activityIDs = database.activities.map(\.id)
        guard Set(activityIDs).count == activityIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs activités dupliqués.")
        }

        let validProjectIDs = Set(projectIDs)
        let invalidActivityProjects = database.activities.contains { validProjectIDs.contains($0.projectID) == false }
        guard invalidActivityProjects == false else {
            throw SamouraiBackupError.invalidPayload("Activité rattachée à un projet inexistant.")
        }

        let activitiesByID = Dictionary(uniqueKeysWithValues: database.activities.map { ($0.id, $0) })
        let invalidActionActivityLink = database.actions.contains { action in
            guard let activityID = action.activityID else { return false }
            guard let activity = activitiesByID[activityID], let actionProjectID = action.projectID else { return true }
            return activity.projectID != actionProjectID
        }
        guard invalidActionActivityLink == false else {
            throw SamouraiBackupError.invalidPayload("Lien action-activité invalide.")
        }

        let meetingIDs = database.meetings.map(\.id)
        guard Set(meetingIDs).count == meetingIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs réunions dupliqués.")
        }

        let decisionIDs = database.decisions.map(\.id)
        guard Set(decisionIDs).count == decisionIDs.count else {
            throw SamouraiBackupError.invalidPayload("IDs décisions dupliqués.")
        }

        return database
    }

    private func sanitizeResourceAssignments(_ resources: [Resource], projectIDs: Set<UUID>) -> [Resource] {
        resources.map { resource in
            var normalizedResource = resource
            normalizedResource.assignedProjectIDs = resource.assignedProjectIDs.filter { projectIDs.contains($0) }
            return normalizedResource
        }
    }

    private func sanitizeActivities(_ activities: [ProjectActivity], projectIDs: Set<UUID>) -> [ProjectActivity] {
        activities
            .filter { projectIDs.contains($0.projectID) }
            .map { activity in
                var normalized = activity
                normalized.estimatedEndDate = max(activity.estimatedEndDate, activity.estimatedStartDate)
                let projectActivityIDs = Set(activities.filter { $0.projectID == activity.projectID }.map(\.id))
                normalized.predecessorActivityIDs = activity.predecessorActivityIDs.filter {
                    $0 != activity.id && projectActivityIDs.contains($0)
                }
                if let project = project(with: activity.projectID) {
                    let validDeliverableIDs = Set(project.deliverables.map(\.id))
                    normalized.linkedDeliverableIDs = activity.linkedDeliverableIDs.filter { validDeliverableIDs.contains($0) }
                } else {
                    normalized.linkedDeliverableIDs = []
                }
                return normalized
            }
    }

    private func sanitizeEvents(_ events: [ProjectEvent], projectIDs: Set<UUID>, resourceIDs: Set<UUID>) -> [ProjectEvent] {
        events.map { event in
            var normalizedEvent = event
            if let projectID = event.projectID, projectIDs.contains(projectID) == false {
                normalizedEvent.projectID = nil
            }
            normalizedEvent.resourceIDs = event.resourceIDs.filter { resourceIDs.contains($0) }
            return normalizedEvent
        }
    }

    private func sanitizeActions(
        _ actions: [ProjectAction],
        projectIDs: Set<UUID>,
        activitiesByID: [UUID: ProjectActivity]
    ) -> [ProjectAction] {
        actions.map { action in
            var normalizedAction = action
            if let projectID = action.projectID, projectIDs.contains(projectID) == false {
                normalizedAction.projectID = nil
            }
            if let activityID = action.activityID {
                guard let activity = activitiesByID[activityID],
                      let actionProjectID = normalizedAction.projectID,
                      activity.projectID == actionProjectID else {
                    normalizedAction.activityID = nil
                    return normalizedAction
                }
            }
            return normalizedAction
        }
    }

    private func sanitizeMeetings(_ meetings: [ProjectMeeting], projectIDs: Set<UUID>) -> [ProjectMeeting] {
        meetings.map { meeting in
            var normalizedMeeting = meeting
            if let projectID = meeting.projectID, projectIDs.contains(projectID) == false {
                normalizedMeeting.projectID = nil
            }
            normalizedMeeting.durationMinutes = max(normalizedMeeting.durationMinutes, 1)
            return normalizedMeeting
        }
    }

    private func sanitizeDecisions(
        _ decisions: [ProjectDecision],
        projectIDs: Set<UUID>,
        meetingIDs: Set<UUID>,
        eventIDs: Set<UUID>,
        resourceIDs: Set<UUID>
    ) -> [ProjectDecision] {
        decisions.map { decision in
            var normalizedDecision = decision
            if let projectID = decision.projectID, projectIDs.contains(projectID) == false {
                normalizedDecision.projectID = nil
            }
            normalizedDecision.meetingIDs = decision.meetingIDs.filter { meetingIDs.contains($0) }
            normalizedDecision.eventIDs = decision.eventIDs.filter { eventIDs.contains($0) }
            normalizedDecision.impactedResourceIDs = decision.impactedResourceIDs.filter { resourceIDs.contains($0) }
            normalizedDecision.history = decision.history.sorted { $0.recordedAt < $1.recordedAt }
            normalizedDecision.comments = decision.comments.sorted { $0.createdAt < $1.createdAt }
            return normalizedDecision
        }
    }

    private func sanitizeGovernanceReports(
        _ reports: [GovernanceReportRecord],
        projectIDs: Set<UUID>
    ) -> [GovernanceReportRecord] {
        reports.map { report in
            var normalized = report
            if let scoped = report.scopedProjectIDs {
                let filtered = scoped.filter { projectIDs.contains($0) }
                normalized.scopedProjectIDs = filtered.isEmpty ? nil : filtered
            }
            return normalized
        }
    }

    private func makeDatabase() -> SamouraiDatabase {
        SamouraiDatabase(
            projects: projects,
            resources: resources,
            unassignedRisks: unassignedRisks,
            activities: activities,
            events: events,
            actions: actions,
            meetings: meetings,
            decisions: decisions,
            governanceReports: governanceReports
        )
    }

    private func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func eventSearchableValues(for event: ProjectEvent) -> [String] {
        var values: [String] = [
            event.title,
            event.details,
            event.source,
            event.priority.label,
            event.happenedAt.formatted(date: .abbreviated, time: .shortened),
            projectName(for: event.projectID)
        ]
        values.append(contentsOf: resourceNames(for: event.resourceIDs))
        return values
    }

    private func actionSearchableValues(for action: ProjectAction) -> [String] {
        let activityTitle = activityTitle(for: action.activityID)
        return [
            action.title,
            action.details,
            action.priority.label,
            action.flow.label,
            activityTitle,
            projectName(for: action.projectID),
            action.dueDate.formatted(date: .abbreviated, time: .omitted),
            action.createdAt.formatted(date: .abbreviated, time: .shortened),
            action.isDone ? "terminée" : "ouverte"
        ]
    }

    private func activityTitle(for activityID: UUID?) -> String {
        guard let activityID else { return "" }
        return activity(with: activityID)?.displayTitle ?? ""
    }

    private func applyActivityLinks(projectID: UUID, activityID: UUID, linkedActionIDs: [UUID]) {
        let eligibleActionIDs = Set(
            actions
                .filter { $0.projectID == projectID }
                .map(\.id)
        )
        let normalizedTargetIDs = Set(linkedActionIDs).intersection(eligibleActionIDs)

        for index in actions.indices {
            guard actions[index].projectID == projectID else { continue }

            if normalizedTargetIDs.contains(actions[index].id) {
                if actions[index].activityID != activityID {
                    actions[index].activityID = activityID
                    actions[index].updatedAt = .now
                }
            } else if actions[index].activityID == activityID {
                actions[index].activityID = nil
                actions[index].updatedAt = .now
            }
        }
    }

    private func activityProgress(for activity: ProjectActivity) -> Double {
        let linkedActions = actions.filter { $0.activityID == activity.id }
        guard linkedActions.isEmpty == false else {
            return activity.actualEndDate == nil ? 0 : 1
        }

        let doneCount = linkedActions.filter(\.isDone).count
        return Double(doneCount) / Double(linkedActions.count)
    }

    private func meetingSearchableValues(for meeting: ProjectMeeting) -> [String] {
        [
            meeting.title,
            projectName(for: meeting.projectID),
            meeting.mode.label,
            meeting.organizer,
            meeting.participants,
            meeting.locationOrLink,
            meeting.notes,
            meeting.transcript,
            meeting.aiSummary,
            meeting.meetingAt.formatted(date: .abbreviated, time: .shortened)
        ]
    }

    private func decisionSearchableValues(for decision: ProjectDecision) -> [String] {
        var values: [String] = [
            decision.title,
            decision.details,
            decision.status.label,
            decision.status.shortLabel,
            "D-\(decision.sequenceNumber)",
            projectName(for: decision.projectID)
        ]

        values.append(contentsOf: decision.comments.map(\.body))
        values.append(contentsOf: decision.history.map(\.summary))

        let meetingTitles = decision.meetingIDs.compactMap { meeting(with: $0)?.displayTitle }
        let eventTitles = decision.eventIDs.compactMap { event(with: $0)?.displayTitle }
        let resourceNames = decision.impactedResourceIDs.compactMap { resource(with: $0)?.displayName }
        values.append(contentsOf: meetingTitles)
        values.append(contentsOf: eventTitles)
        values.append(contentsOf: resourceNames)

        return values
    }

    private func hasGoNoGoDecision(projectID: UUID) -> Bool {
        decisions.contains { decision in
            guard decision.projectID == projectID else { return false }
            let normalizedTitle = normalizedToken(decision.title)
            return normalizedTitle.contains("go / no-go")
                || normalizedTitle.contains("go/no-go")
                || normalizedTitle.contains("go no-go")
                || normalizedTitle.contains("go no go")
        }
    }

    private func sanitizedProjectID(_ projectID: UUID?) -> UUID? {
        guard let projectID else { return nil }
        return projects.contains(where: { $0.id == projectID }) ? projectID : nil
    }

    private func sanitizedDeliverableIDs(projectID: UUID, deliverableIDs: [UUID]) -> [UUID] {
        guard let project = project(with: projectID) else { return [] }
        let validIDs = Set(project.deliverables.map(\.id))
        var seen = Set<UUID>()
        return deliverableIDs.filter { deliverableID in
            guard validIDs.contains(deliverableID) else { return false }
            return seen.insert(deliverableID).inserted
        }
    }

    private func sanitizedPredecessorActivityIDs(
        projectID: UUID,
        predecessorIDs: [UUID],
        currentActivityID: UUID?
    ) -> [UUID] {
        let validIDs = Set(activities(for: projectID).map(\.id))
        var seen = Set<UUID>()
        return predecessorIDs.filter { predecessorID in
            if let currentActivityID, predecessorID == currentActivityID {
                return false
            }
            guard validIDs.contains(predecessorID) else { return false }
            return seen.insert(predecessorID).inserted
        }
    }

    private func sanitizedResourceIDs(_ resourceIDs: [UUID]) -> [UUID] {
        let validIDs = Set(resources.map(\.id))
        var seen = Set<UUID>()
        return resourceIDs.filter { resourceID in
            guard validIDs.contains(resourceID) else { return false }
            return seen.insert(resourceID).inserted
        }
    }

    private func sanitizedMeetingIDs(_ meetingIDs: [UUID]) -> [UUID] {
        let validIDs = Set(meetings.map(\.id))
        var seen = Set<UUID>()
        return meetingIDs.filter { meetingID in
            guard validIDs.contains(meetingID) else { return false }
            return seen.insert(meetingID).inserted
        }
    }

    private func sanitizedEventIDs(_ eventIDs: [UUID]) -> [UUID] {
        let validIDs = Set(events.map(\.id))
        var seen = Set<UUID>()
        return eventIDs.filter { eventID in
            guard validIDs.contains(eventID) else { return false }
            return seen.insert(eventID).inserted
        }
    }

    private func nextDecisionSequenceNumber() -> Int {
        (decisions.map(\.sequenceNumber).max() ?? 0) + 1
    }

    private func normalizedScopeItems(_ items: [String]) -> [String] {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return cleaned.reduce(into: [String]()) { partial, value in
            if partial.contains(value) == false {
                partial.append(value)
            }
        }
    }

    private func normalizedAcceptanceCriteria(_ criteria: [String]) -> [DeliverableAcceptanceCriterion] {
        normalizedScopeItems(criteria).map { DeliverableAcceptanceCriterion(text: $0) }
    }

    private typealias ReportingDateRange = (start: Date, endExclusive: Date)

    private func reportingScopedProjects(scopedProjectIDs: [UUID]?) -> [Project] {
        guard let scopedProjectIDs else { return projects }
        let set = Set(scopedProjectIDs)
        return projects.filter { set.contains($0.id) }
    }

    private func reportingPeriod(cadence: ReportingCadence, referenceDate: Date) -> ReportingDateRange {
        let calendar = Calendar.current
        let referenceStart = calendar.startOfDay(for: referenceDate)

        switch cadence {
        case .weekly:
            let start = calendar.date(byAdding: .day, value: -6, to: referenceStart) ?? referenceStart
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: referenceStart) ?? referenceStart
            return (start, endExclusive)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: referenceDate)
            let monthStart = calendar.date(from: components) ?? referenceStart
            let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return (monthStart, nextMonthStart)
        }
    }

    private func reportingPreviousPeriod(current: ReportingDateRange) -> ReportingDateRange {
        let interval = current.endExclusive.timeIntervalSince(current.start)
        let previousEnd = current.start
        let previousStart = previousEnd.addingTimeInterval(-interval)
        return (previousStart, previousEnd)
    }

    private func reportingContains(_ date: Date, in range: ReportingDateRange) -> Bool {
        date >= range.start && date < range.endExclusive
    }

    private func reportingGlobalHealth(for projects: [Project]) -> ProjectHealth {
        if projects.contains(where: { $0.health == .red }) {
            return .red
        }
        if projects.contains(where: { $0.health == .amber }) {
            return .amber
        }
        return .green
    }

    private func reportingGlobalTestsRAGStatus(projects: [Project]) -> ProjectTestingRAGStatus {
        if projects.contains(where: { $0.testingRAGStatus == .red }) {
            return .red
        }
        if projects.contains(where: { $0.testingRAGStatus == .amber }) {
            return .amber
        }
        return .green
    }

    private func reportingGlobalProgressPercent(projects: [Project], activities: [ProjectActivity]) -> Int {
        guard projects.isEmpty == false else { return 0 }

        let byProjectID = Dictionary(grouping: activities, by: \.projectID)
        let projectScores: [Double] = projects.map { project in
            var components: [Double] = []

            if project.deliverables.isEmpty == false {
                components.append(project.completionRatio)
            }

            let projectActivities = byProjectID[project.id] ?? []
            if projectActivities.isEmpty == false {
                let completed = projectActivities.filter(\.isCompleted).count
                components.append(Double(completed) / Double(projectActivities.count))
            }

            guard components.isEmpty == false else { return 0 }
            return components.reduce(0, +) / Double(components.count)
        }

        let mean = projectScores.reduce(0, +) / Double(projectScores.count)
        return Int((mean * 100).rounded())
    }

    private func reportingCriticalRiskCount(projects: [Project], asOf date: Date) -> Int {
        projects
            .flatMap(\.risks)
            .filter { $0.severity == .critical && $0.createdAt < date }
            .count
    }

    private func reportingTestsAveragePercent(projects: [Project]) -> Int {
        guard projects.isEmpty == false else { return 0 }
        let total = projects.reduce(0) { $0 + $1.testingAverageProgressPercent }
        return Int((Double(total) / Double(projects.count)).rounded())
    }

    private func reportingAccomplishments(
        projects: [Project],
        activities: [ProjectActivity],
        decisions: [ProjectDecision],
        period: ReportingDateRange
    ) -> [String] {
        let completedDeliverables = projects.flatMap { project in
            project.deliverables.compactMap { deliverable -> String? in
                guard deliverable.isDone else { return nil }
                let inPeriod = reportingContains(deliverable.dueDate, in: period)
                    || reportingContains(deliverable.createdAt, in: period)
                guard inPeriod else { return nil }
                return "[\(project.name)] Livrable terminé: \(deliverable.title)"
            }
        }

        let closedActivities = activities.compactMap { activity -> String? in
            guard let closedAt = activity.actualEndDate, reportingContains(closedAt, in: period) else { return nil }
            let projectName = project(with: activity.projectID)?.name ?? "Projet"
            if activity.isMilestone {
                return "[\(projectName)] Jalon atteint: \(activity.displayTitle)"
            }
            return "[\(projectName)] Activité clôturée: \(activity.displayTitle)"
        }

        let touchedDecisions = decisions.compactMap { decision -> String? in
            let created = reportingContains(decision.createdAt, in: period)
            let updated = reportingContains(decision.updatedAt, in: period)
            guard created || updated else { return nil }
            let projectName = projectName(for: decision.projectID)
            return created
                ? "[\(projectName)] Décision prise: \(decision.displayTitle)"
                : "[\(projectName)] Décision mise à jour: \(decision.displayTitle)"
        }

        return (completedDeliverables + closedActivities + touchedDecisions)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func reportingVariancesAndChanges(
        projects: [Project],
        actions: [ProjectAction],
        period: ReportingDateRange,
        previousPeriod: ReportingDateRange,
        referenceDate: Date
    ) -> [String] {
        var items: [String] = []

        let tensionProjects = projects.filter { $0.health != .green }
        items.append(contentsOf: tensionProjects.map { project in
            "[\(project.name)] Statut projet sous surveillance: \(project.health.label)"
        })

        let newCriticalRisks = projects.flatMap { project in
            project.risks.compactMap { risk -> String? in
                guard risk.severity == .critical, reportingContains(risk.createdAt, in: period) else { return nil }
                return "[\(project.name)] Nouveau risque critique: \(risk.displayTitle)"
            }
        }
        items.append(contentsOf: newCriticalRisks)

        let currentCritical = reportingCriticalRiskCount(projects: projects, asOf: period.endExclusive)
        let previousCritical = reportingCriticalRiskCount(projects: projects, asOf: previousPeriod.endExclusive)
        let delta = currentCritical - previousCritical
        if delta != 0 {
            let direction = delta > 0 ? "hausse" : "baisse"
            items.append("Évolution risques critiques: \(direction) de \(abs(delta)) vs période précédente.")
        }

        let testSignals = projects.flatMap { project in
            project.orderedTestingPhases
                .filter { $0.kind == .ist || $0.kind == .uat }
                .compactMap { phase -> String? in
                    if phase.isBlocked {
                        return "[\(project.name)] \(phase.kind.shortLabel) bloquée."
                    }
                    if phase.isDelayed {
                        return "[\(project.name)] \(phase.kind.shortLabel) en retard sur la date estimée."
                    }
                    if phase.isCompleted {
                        return "[\(project.name)] \(phase.kind.shortLabel) finalisée."
                    }
                    return nil
                }
        }
        items.append(contentsOf: testSignals)

        let overdueActions = actions
            .filter { !$0.isDone && $0.dueDate < referenceDate }
            .map { action in
                let projectName = projectName(for: action.projectID)
                return "[\(projectName)] Action en retard: \(action.displayTitle) (échéance \(action.dueDate.formatted(date: .abbreviated, time: .omitted)))."
            }
        items.append(contentsOf: overdueActions)

        return items.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func reportingNextSteps(
        projects: [Project],
        activities: [ProjectActivity],
        actions: [ProjectAction],
        referenceDate: Date,
        horizonDays: Int
    ) -> [String] {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(for: referenceDate)
        let windowEnd = calendar.date(byAdding: .day, value: max(horizonDays, 1), to: windowStart) ?? windowStart
        let range: ReportingDateRange = (windowStart, windowEnd)

        let upcomingDeliverables = projects.flatMap { project in
            project.deliverables.compactMap { deliverable -> String? in
                guard deliverable.isDone == false, reportingContains(deliverable.dueDate, in: range) else { return nil }
                return "[\(project.name)] Livrable attendu: \(deliverable.title) (\(deliverable.dueDate.formatted(date: .abbreviated, time: .omitted)))."
            }
        }

        let upcomingActivities = activities.compactMap { activity -> String? in
            guard activity.isCompleted == false, reportingContains(activity.estimatedEndDate, in: range) else { return nil }
            let projectName = project(with: activity.projectID)?.name ?? "Projet"
            let prefix = activity.isMilestone ? "Jalon attendu" : "Activité clé attendue"
            return "[\(projectName)] \(prefix): \(activity.displayTitle) (\(activity.estimatedEndDate.formatted(date: .abbreviated, time: .omitted)))."
        }

        let upcomingActions = actions.compactMap { action -> String? in
            guard action.isDone == false, reportingContains(action.dueDate, in: range) else { return nil }
            let projectName = projectName(for: action.projectID)
            return "[\(projectName)] Action PM à venir: \(action.displayTitle) (\(action.dueDate.formatted(date: .abbreviated, time: .omitted)))."
        }

        return (upcomingDeliverables + upcomingActivities + upcomingActions)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func normalizedCriterionScores(_ scores: [ResourceCriterionScore]) -> [ResourceCriterionScore] {
        let scoreByCriterion = Dictionary(uniqueKeysWithValues: scores.map { ($0.criterion, $0.score) })
        return ResourceEvaluationCriterion.allCases.map { criterion in
            ResourceCriterionScore(
                criterion: criterion,
                score: scoreByCriterion[criterion] ?? .satisfaisant
            )
        }
    }

    private func scopedEvaluations(for resource: Resource, projectID: UUID?) -> [ResourcePerformanceEvaluation] {
        let sorted = resource.performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        guard let projectID else { return sorted }
        return sorted.filter { $0.projectID == nil || $0.projectID == projectID }
    }

    private func makePerformanceSnapshot(for resource: Resource, scopedProjectID: UUID?) -> ResourcePerformanceSnapshot {
        let allScoped = scopedEvaluations(for: resource, projectID: scopedProjectID)
        let latest = allScoped.last
        let trend = trendForEvaluations(allScoped)
        let groupAverage = groupAverageLatestScore(scopedProjectID: scopedProjectID, excluding: resource.id)
        let alerts = alertsForEvaluations(allScoped, trend: trend, groupAverage: groupAverage)

        return ResourcePerformanceSnapshot(
            resourceID: resource.id,
            resourceName: resource.displayName,
            latestScore: latest?.weightedScore,
            trend: trend,
            alerts: alerts
        )
    }

    private func groupAverageLatestScore(scopedProjectID: UUID?, excluding resourceID: UUID) -> Double? {
        let scoped: [Resource]
        if let scopedProjectID {
            scoped = resources(for: scopedProjectID)
        } else {
            scoped = resources
        }

        let values = scoped
            .filter { $0.id != resourceID }
            .compactMap { resource -> Double? in
                scopedEvaluations(for: resource, projectID: scopedProjectID).last?.weightedScore
            }
        guard values.isEmpty == false else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    private func trendForEvaluations(_ evaluations: [ResourcePerformanceEvaluation]) -> ResourcePerformanceTrend {
        let recent = Array(evaluations.suffix(3))
        guard recent.count >= 2 else { return .stable }
        guard let first = recent.first?.weightedScore, let last = recent.last?.weightedScore else { return .stable }
        let delta = last - first
        if delta <= -0.6 { return .degrading }
        if delta >= 0.6 { return .improving }
        return .stable
    }

    private func alertsForEvaluations(
        _ evaluations: [ResourcePerformanceEvaluation],
        trend: ResourcePerformanceTrend,
        groupAverage: Double?
    ) -> [ResourcePerformanceAlert] {
        guard evaluations.isEmpty == false else { return [] }

        var alerts: [ResourcePerformanceAlert] = []
        if trend == .degrading {
            alerts.append(
                ResourcePerformanceAlert(
                    kind: .sustainedDegradation,
                    message: "La trajectoire des 3 derniers points de contrôle est en baisse."
                )
            )
        }

        if let latest = evaluations.last?.weightedScore, let groupAverage, latest <= groupAverage - 1.0 {
            alerts.append(
                ResourcePerformanceAlert(
                    kind: .belowGroupAverage,
                    message: "La note (\(String(format: "%.2f", latest))/5) est significativement sous la moyenne du groupe (\(String(format: "%.2f", groupAverage))/5)."
                )
            )
        }

        return alerts
    }

    private func resourceMatchingKey(fullName: String, jobTitle: String) -> String {
        let normalizedFullName = fullName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedJobTitle = jobTitle
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "\(normalizedFullName)|\(normalizedJobTitle)"
    }

    private func normalizedResourceFields(
        nom: String?,
        parentDescription: String?,
        primaryResourceRole: String?,
        resourceRoles: String?,
        organizationalResource: String?,
        competence1: String? = nil,
        resourceCalendar: String? = nil,
        resourceStartDate: Date? = nil,
        resourceFinishDate: Date? = nil,
        responsableOperationnel: String? = nil,
        responsableInterne: String? = nil,
        localisation: String? = nil,
        typeDeRessource: String? = nil,
        journeesTempsPartiel: String? = nil
    ) -> NormalizedResourceFields {
        let normalizedNom = cleanedOptionalString(nom)
        let normalizedParentDescription = cleanedOptionalString(parentDescription)
        let normalizedPrimaryRole = cleanedOptionalString(primaryResourceRole)
        let normalizedRoles = cleanedOptionalString(resourceRoles)
        let normalizedOrganizationalResource = cleanedOptionalString(organizationalResource)
        let normalizedCompetence = cleanedOptionalString(competence1)
        let normalizedCalendar = cleanedOptionalString(resourceCalendar)
        let normalizedOperationalManager = cleanedOptionalString(responsableOperationnel)
        let normalizedInternalManager = cleanedOptionalString(responsableInterne)
        let normalizedLocation = cleanedOptionalString(localisation)
        let normalizedResourceType = cleanedOptionalString(typeDeRessource)
        let normalizedPartTimeDays = cleanedOptionalString(journeesTempsPartiel)

        return NormalizedResourceFields(
            fullName: normalizedNom ?? "",
            jobTitle: normalizedPrimaryRole ?? normalizedRoles ?? "",
            department: normalizedParentDescription ?? normalizedOrganizationalResource ?? "",
            nom: normalizedNom,
            parentDescription: normalizedParentDescription,
            primaryResourceRole: normalizedPrimaryRole,
            resourceRoles: normalizedRoles,
            organizationalResource: normalizedOrganizationalResource,
            competence1: normalizedCompetence,
            resourceCalendar: normalizedCalendar,
            resourceStartDate: resourceStartDate,
            resourceFinishDate: resourceFinishDate,
            responsableOperationnel: normalizedOperationalManager,
            responsableInterne: normalizedInternalManager,
            localisation: normalizedLocation,
            typeDeRessource: normalizedResourceType,
            journeesTempsPartiel: normalizedPartTimeDays,
            engagement: resourceEngagement(from: normalizedResourceType),
            status: resourceStatus(resourceFinishDate: resourceFinishDate, journeesTempsPartiel: normalizedPartTimeDays),
            allocationPercent: resourceAllocationPercent(from: normalizedPartTimeDays)
        )
    }

    private func cleanedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    private func resourceEngagement(from typeDeRessource: String?) -> ResourceEngagement {
        let normalized = (typeDeRessource ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if normalized.contains("freelance") || normalized.contains("contractor") {
            return .freelancer
        }

        if normalized.contains("prestataire") || normalized.contains("consult") || normalized.contains("external") {
            return .externalConsultant
        }

        return .internalEmployee
    }

    private func resourceStatus(resourceFinishDate: Date?, journeesTempsPartiel: String?) -> ResourceStatus {
        if let resourceFinishDate, resourceFinishDate < Calendar.current.startOfDay(for: .now) {
            return .offboarded
        }

        if resourceAllocationPercent(from: journeesTempsPartiel) < 100 {
            return .partiallyAvailable
        }

        return .active
    }

    private func resourceAllocationPercent(from journeesTempsPartiel: String?) -> Int {
        let cleaned = (journeesTempsPartiel ?? "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")

        guard let numericValue = Double(cleaned), numericValue.isFinite else {
            return 100
        }

        if numericValue > 5 {
            return min(max(Int(numericValue.rounded()), 0), 100)
        }

        let allocation = ((5.0 - numericValue) / 5.0) * 100.0
        let rounded = Int((allocation / 5.0).rounded() * 5.0)
        return min(max(rounded, 0), 100)
    }

    private func sortStandaloneRisks(_ risks: [Risk]) -> [Risk] {
        risks.sorted {
            if $0.severity.sortWeight == $1.severity.sortWeight {
                return $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
            }
            return $0.severity.sortWeight > $1.severity.sortWeight
        }
    }

    private enum RiskLocation {
        case project(projectIndex: Int, riskIndex: Int)
        case unassigned(riskIndex: Int)
    }

    private func findRiskLocation(by matchingKey: String) -> RiskLocation? {
        for (projectIndex, project) in projects.enumerated() {
            if let riskIndex = project.risks.firstIndex(where: {
                riskMatchingKey(externalID: $0.externalID, title: $0.displayTitle) == matchingKey
            }) {
                return .project(projectIndex: projectIndex, riskIndex: riskIndex)
            }
        }

        if let riskIndex = unassignedRisks.firstIndex(where: {
            riskMatchingKey(externalID: $0.externalID, title: $0.displayTitle) == matchingKey
        }) {
            return .unassigned(riskIndex: riskIndex)
        }

        return nil
    }

    private func riskMatchingKey(externalID: String?, title: String) -> String {
        let normalizedID = (externalID ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizedID.isEmpty ? normalizedTitle : "\(normalizedID)|\(normalizedTitle)"
    }

    private func resolveProjectID(from rawProjects: String?) -> UUID? {
        guard let rawProjects else { return nil }

        let projectTokens = rawProjects
            .split(whereSeparator: { [",", ";", "|"].contains($0) })
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            }
            .filter { $0.isEmpty == false }

        guard projectTokens.isEmpty == false else { return nil }

        return projects.first(where: { project in
            let normalizedProjectName = project.name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return projectTokens.contains(where: { token in normalizedProjectName.contains(token) || token.contains(normalizedProjectName) })
        })?.id
    }

    private func normalizedRiskFields(from draft: RiskImportDraft) -> (risk: Risk, displayTitle: String, externalID: String?) {
        let displayTitle = cleanedOptionalString(draft.riskTitle) ?? "Risque"
        let externalID = cleanedOptionalString(draft.externalID)
        let assignedTo = cleanedOptionalString(draft.assignedTo)
        let counterMeasure = cleanedOptionalString(draft.counterMeasure)
        let createdAt = draft.dateCreated ?? .now
        let score = draft.score0to10
        let severity = riskSeverity(from: score)

        let risk = Risk(
            title: displayTitle,
            mitigation: counterMeasure ?? "",
            owner: assignedTo ?? "",
            severity: severity,
            dueDate: nil,
            createdAt: createdAt,
            externalID: externalID,
            projectNames: cleanedOptionalString(draft.projectNames),
            detectedBy: cleanedOptionalString(draft.detectedBy),
            assignedTo: assignedTo,
            lastModifiedAt: draft.lastModifiedAt,
            riskType: cleanedOptionalString(draft.riskType),
            response: cleanedOptionalString(draft.response),
            riskTitle: cleanedOptionalString(draft.riskTitle),
            riskOrigin: cleanedOptionalString(draft.riskOrigin),
            impactDescription: cleanedOptionalString(draft.impactDescription),
            counterMeasure: counterMeasure,
            followUpComment: cleanedOptionalString(draft.followUpComment),
            proximity: cleanedOptionalString(draft.proximity),
            probability: cleanedOptionalString(draft.probability),
            impactScope: cleanedOptionalString(draft.impactScope),
            impactBudget: cleanedOptionalString(draft.impactBudget),
            impactPlanning: cleanedOptionalString(draft.impactPlanning),
            impactResources: cleanedOptionalString(draft.impactResources),
            impactTransition: cleanedOptionalString(draft.impactTransition),
            impactSecurityIT: cleanedOptionalString(draft.impactSecurityIT),
            escalationLevel: cleanedOptionalString(draft.escalationLevel),
            riskStatus: cleanedOptionalString(draft.riskStatus),
            score0to10: score
        )

        return (risk, displayTitle, externalID)
    }

    private func riskSeverity(from score: Double?) -> RiskSeverity {
        guard let score else { return .medium }
        switch score {
        case 8...10:
            return .critical
        case 6..<8:
            return .high
        case 4..<6:
            return .medium
        default:
            return .low
        }
    }
}

enum SamouraiSeedFactory {
    static func makeDemoProjects() -> [Project] {
        let today = Date.now
        let calendar = Calendar.current

        let rolloutProject = Project(
            name: "Refonte Portail Client",
            summary: "Projet structurant avec cadrage fort, planning stabilisé et delivery piloté par lots.",
            sponsor: "Direction Digitale",
            manager: "Chef de projet Samourai",
            phase: .delivery,
            health: .amber,
            deliveryMode: .hybrid,
            startDate: calendar.date(byAdding: .day, value: -42, to: today) ?? today,
            targetDate: calendar.date(byAdding: .day, value: 65, to: today) ?? today,
            risks: [
                Risk(
                    title: "Dépendance API partenaire encore instable",
                    mitigation: "Verrouiller un mode dégradé et obtenir une date d'engagement ferme côté partenaire.",
                    owner: "Tech Lead",
                    severity: .critical,
                    dueDate: calendar.date(byAdding: .day, value: 7, to: today)
                ),
                Risk(
                    title: "Validation métier sur parcours sensible",
                    mitigation: "Planifier une revue sponsor et arbitrer le périmètre strictement nécessaire au lot 1.",
                    owner: "PO Métier",
                    severity: .high,
                    dueDate: calendar.date(byAdding: .day, value: 10, to: today)
                )
            ],
            deliverables: [
                Deliverable(
                    title: "Dossier de cadrage signé",
                    details: "Version consolidée validée sponsor et architecture.",
                    owner: "Chef de projet",
                    dueDate: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
                    isDone: true
                ),
                Deliverable(
                    title: "Pack UAT lot 1",
                    details: "Jeux de tests, environnement et critères de go/no-go.",
                    owner: "QA Lead",
                    dueDate: calendar.date(byAdding: .day, value: 16, to: today) ?? today
                )
            ]
        )

        let dataProject = Project(
            name: "Industrialisation Reporting Finance",
            summary: "Sécurisation des livrables réglementaires avec gouvernance waterfall et sprints de finition.",
            sponsor: "CFO Office",
            manager: "PMO Samourai",
            phase: .planning,
            health: .green,
            deliveryMode: .waterfall,
            startDate: calendar.date(byAdding: .day, value: -18, to: today) ?? today,
            targetDate: calendar.date(byAdding: .day, value: 95, to: today) ?? today,
            risks: [
                Risk(
                    title: "Disponibilité limitée des contrôleurs financiers",
                    mitigation: "Bloquer des créneaux hebdo et préparer des supports de validation en asynchrone.",
                    owner: "PMO",
                    severity: .medium,
                    dueDate: calendar.date(byAdding: .day, value: 14, to: today)
                )
            ],
            deliverables: [
                Deliverable(
                    title: "Planning consolidé comité projet",
                    details: "Version baseline avec jalons, charges et fenêtres de validation.",
                    owner: "PMO",
                    dueDate: calendar.date(byAdding: .day, value: 6, to: today) ?? today
                ),
                Deliverable(
                    title: "Backlog de finition priorisé",
                    details: "Liste des sujets delivery à traiter en séquence courte.",
                    owner: "Business Analyst",
                    dueDate: calendar.date(byAdding: .day, value: 21, to: today) ?? today
                )
            ]
        )

        return [rolloutProject, dataProject].sorted { $0.targetDate < $1.targetDate }
    }

    static func makeDemoResources(projects: [Project]) -> [Resource] {
        let rolloutProjectID = projects.first(where: { $0.name == "Refonte Portail Client" })?.id
        let dataProjectID = projects.first(where: { $0.name == "Industrialisation Reporting Finance" })?.id

        return [
            Resource(
                fullName: "Claire Bernard",
                jobTitle: "PMO Delivery",
                department: "Transformation",
                email: "claire.bernard@samourai.local",
                phone: "+32 470 10 20 30",
                engagement: .internalEmployee,
                status: .active,
                allocationPercent: 80,
                assignedProjectIDs: [rolloutProjectID].compactMap { $0 },
                notes: "Pilote les comités hebdomadaires et sécurise les arbitrages delivery."
            ),
            Resource(
                fullName: "Idriss Mahjoub",
                jobTitle: "Tech Lead",
                department: "Engineering",
                email: "idriss.mahjoub@samourai.local",
                phone: "+32 470 11 22 33",
                engagement: .externalConsultant,
                status: .partiallyAvailable,
                allocationPercent: 60,
                assignedProjectIDs: [rolloutProjectID].compactMap { $0 },
                notes: "Point de tension principal sur les dépendances API et les arbitrages de dette technique."
            ),
            Resource(
                fullName: "Sophie Lambert",
                jobTitle: "Business Analyst",
                department: "Finance",
                email: "sophie.lambert@samourai.local",
                phone: "+32 470 44 55 66",
                engagement: .internalEmployee,
                status: .active,
                allocationPercent: 70,
                assignedProjectIDs: [dataProjectID].compactMap { $0 },
                notes: "Prépare les validations métier et consolide les besoins réglementaires."
            )
        ]
        .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }
}
