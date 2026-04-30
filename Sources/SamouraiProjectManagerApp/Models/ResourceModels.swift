import Foundation

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
            case .qualityDeliverable: return 0.20
            case .deadlineCompliance: return 0.15
            case .technicalFit: return 0.25
            case .reliability: return 0.10
            case .collaboration: return 0.30
            }
        case .planning:
            switch self {
            case .qualityDeliverable: return 0.25
            case .deadlineCompliance: return 0.20
            case .technicalFit: return 0.25
            case .reliability: return 0.15
            case .collaboration: return 0.15
            }
        case .delivery:
            switch self {
            case .qualityDeliverable: return 0.25
            case .deadlineCompliance: return 0.30
            case .technicalFit: return 0.20
            case .reliability: return 0.20
            case .collaboration: return 0.05
            }
        case .stabilisation:
            switch self {
            case .qualityDeliverable: return 0.25
            case .deadlineCompliance: return 0.15
            case .technicalFit: return 0.20
            case .reliability: return 0.35
            case .collaboration: return 0.05
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
    /// Identifiant de la ressource template dont cette ressource de projet est issue (0..1).
    var templateResourceID: UUID?
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
        templateResourceID: UUID? = nil,
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
        self.templateResourceID = templateResourceID
        self.performanceEvaluations = performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, fullName, jobTitle, department, nom, parentDescription
        case primaryResourceRole, resourceRoles, organizationalResource, competence1
        case resourceCalendar, resourceStartDate, resourceFinishDate
        case responsableOperationnel, responsableInterne, localisation
        case typeDeRessource, journeesTempsPartiel, email, phone
        case engagement, status, allocationPercent
        case assignedProjectIDs, favoriteProjectIDs, assignedProjectID
        case templateResourceID
        case performanceEvaluations, notes, createdAt, updatedAt
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

        templateResourceID = try container.decodeIfPresent(UUID.self, forKey: .templateResourceID)

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
        try container.encodeIfPresent(templateResourceID, forKey: .templateResourceID)
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

    var isActivelyContributing: Bool {
        status == .active || status == .partiallyAvailable
    }
}
