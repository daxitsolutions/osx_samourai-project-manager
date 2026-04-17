import Foundation
import Observation

struct SamouraiDatabase: Codable {
    var projects: [Project]
    var resources: [Resource]
    var unassignedRisks: [Risk] = []

    static let empty = SamouraiDatabase(projects: [], resources: [])
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

    private(set) var projects: [Project] = []
    private(set) var resources: [Resource] = []
    private(set) var unassignedRisks: [Risk] = []
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
                try await persistence.save(makeDatabase())
            } else {
                projects = sortProjects(database.projects)
                resources = sortResources(database.resources)
                unassignedRisks = sortStandaloneRisks(database.unassignedRisks)
            }
        } catch {
            lastErrorMessage = "Chargement impossible : \(error.localizedDescription)"

            if projects.isEmpty {
                let seededProjects = SamouraiSeedFactory.makeDemoProjects()
                let seededResources = SamouraiSeedFactory.makeDemoResources(projects: seededProjects)
                projects = sortProjects(seededProjects)
                resources = sortResources(seededResources)
                unassignedRisks = []
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

    func resources(for projectID: UUID) -> [Resource] {
        resources
            .filter { $0.assignedProjectID == projectID }
            .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
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
        dueDate: Date
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        let deliverable = Deliverable(
            title: title,
            details: details,
            owner: owner,
            dueDate: dueDate
        )

        projects[index].deliverables.append(deliverable)
        projects[index].updatedAt = .now
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
        assignedProjectID: UUID?,
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
            assignedProjectID: assignedProjectID,
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
        assignedProjectID: UUID?,
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
        resources[index].assignedProjectID = assignedProjectID
        resources[index].notes = notes
        resources[index].updatedAt = .now
        resources = sortResources(resources)
        persist()
    }

    func deleteResource(resourceID: UUID) {
        resources.removeAll { $0.id == resourceID }
        persist()
    }

    func importResources(_ drafts: [ResourceImportDraft]) -> ResourceImportResult {
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        var firstImportedOrUpdatedResourceID: UUID?

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
                skippedCount += 1
                continue
            }

            let normalizedKey = resourceMatchingKey(fullName: normalized.fullName, jobTitle: normalized.jobTitle)

            if let index = resources.firstIndex(where: {
                resourceMatchingKey(fullName: $0.fullName, jobTitle: $0.jobTitle) == normalizedKey
            }) {
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
                resources[index].engagement = normalized.engagement
                resources[index].status = normalized.status
                resources[index].allocationPercent = normalized.allocationPercent
                resources[index].notes = trimmedNotes
                resources[index].updatedAt = .now
                updatedCount += 1

                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = resources[index].id
                }
            } else {
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
                    email: "",
                    phone: "",
                    engagement: normalized.engagement,
                    status: normalized.status,
                    allocationPercent: normalized.allocationPercent,
                    assignedProjectID: nil,
                    notes: trimmedNotes
                )

                resources.append(resource)
                importedCount += 1

                if firstImportedOrUpdatedResourceID == nil {
                    firstImportedOrUpdatedResourceID = resource.id
                }
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

    private func makeDatabase() -> SamouraiDatabase {
        SamouraiDatabase(projects: projects, resources: resources, unassignedRisks: unassignedRisks)
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
                assignedProjectID: rolloutProjectID,
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
                assignedProjectID: rolloutProjectID,
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
                assignedProjectID: dataProjectID,
                notes: "Prépare les validations métier et consolide les besoins réglementaires."
            )
        ]
        .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }
}
