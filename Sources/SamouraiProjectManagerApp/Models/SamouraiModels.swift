import Foundation

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
        deliverables: [Deliverable] = []
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
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        owner: String,
        dueDate: Date,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.owner = owner
        self.dueDate = dueDate
        self.isDone = isDone
        self.createdAt = createdAt
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
    var assignedProjectID: UUID?
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
        assignedProjectID: UUID? = nil,
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
        self.assignedProjectID = assignedProjectID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Resource {
    var allocationLabel: String {
        "\(allocationPercent)%"
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
        switch self {
        case .green:
            "green"
        case .amber:
            "orange"
        case .red:
            "red"
        }
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
        switch self {
        case .active:
            "green"
        case .partiallyAvailable:
            "orange"
        case .onLeave:
            "yellow"
        case .offboarded:
            "gray"
        }
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
