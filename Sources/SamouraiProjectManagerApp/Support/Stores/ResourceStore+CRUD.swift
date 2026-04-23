import Foundation

struct NormalizedResourceFieldsStore {
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

extension ResourceStore {
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
        return resource.id
    }

    @discardableResult
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
    ) -> Bool {
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return false }

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
        resources[index].favoriteProjectIDs = resources[index].favoriteProjectIDs.filter { assignedProjectIDs.contains($0) }
        resources[index].notes = notes
        resources[index].updatedAt = .now
        resources = sortResources(resources)
        return true
    }

    @discardableResult
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
    ) -> Bool {
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return false }

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
        return true
    }

    @discardableResult
    func assignResource(resourceID: UUID, to projectID: UUID, validProjectIDs: Set<UUID>) -> Bool {
        guard validProjectIDs.contains(projectID) else { return false }
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return false }
        guard resources[index].assignedProjectIDs.contains(projectID) == false else { return false }

        resources[index].assignedProjectIDs.append(projectID)
        resources[index].updatedAt = .now
        resources = sortResources(resources)
        return true
    }

    @discardableResult
    func toggleFavoriteResource(resourceID: UUID, in projectID: UUID, validProjectIDs: Set<UUID>) -> Bool {
        guard validProjectIDs.contains(projectID) else { return false }
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return false }
        guard resources[index].assignedProjectIDs.contains(projectID) else { return false }

        if resources[index].favoriteProjectIDs.contains(projectID) {
            resources[index].favoriteProjectIDs.removeAll { $0 == projectID }
        } else {
            resources[index].favoriteProjectIDs.append(projectID)
        }

        resources[index].updatedAt = .now
        resources = sortResources(resources)
        return true
    }

    @discardableResult
    func unassignResource(resourceID: UUID, from projectID: UUID) -> Bool {
        guard let index = resources.firstIndex(where: { $0.id == resourceID }) else { return false }
        let previousAssignments = resources[index].assignedProjectIDs
        resources[index].assignedProjectIDs.removeAll { $0 == projectID }
        guard resources[index].assignedProjectIDs != previousAssignments else { return false }

        resources[index].favoriteProjectIDs.removeAll { $0 == projectID }
        resources[index].updatedAt = .now
        resources = sortResources(resources)
        return true
    }

    @discardableResult
    func deleteResource(resourceID: UUID) -> Bool {
        let previousCount = resources.count
        resources.removeAll { $0.id == resourceID }
        return resources.count != previousCount
    }

    func sortResources(_ resources: [Resource]) -> [Resource] {
        resources.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    func normalizedResourceFields(
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
    ) -> NormalizedResourceFieldsStore {
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

        return NormalizedResourceFieldsStore(
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

    func cleanedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    func resourceEngagement(from typeDeRessource: String?) -> ResourceEngagement {
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

    func resourceStatus(resourceFinishDate: Date?, journeesTempsPartiel: String?) -> ResourceStatus {
        if let resourceFinishDate, resourceFinishDate < Calendar.current.startOfDay(for: .now) {
            return .offboarded
        }

        if resourceAllocationPercent(from: journeesTempsPartiel) < 100 {
            return .partiallyAvailable
        }

        return .active
    }

    func resourceAllocationPercent(from journeesTempsPartiel: String?) -> Int {
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
}
