import Foundation

extension ResourceStore {
    struct MergeExistingResourceResult {
        let mergedResource: Resource
        let changes: [ResourceImportFieldChange]
    }

    func makeResourceImportReviewItem(for draft: ResourceImportDraft) -> ResourceImportReviewItem {
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = cleanedOptionalString(draft.email)
        let normalizedPhone = cleanedOptionalString(draft.phone)
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
            return ResourceImportReviewItem(
                sourceRowNumber: draft.sourceRowNumber,
                action: .skipped,
                resourceID: nil,
                displayName: "(ligne sans nom)",
                changes: [],
                proposedResource: nil,
                isExistingResource: false
            )
        }

        let normalizedKey = resourceMatchingKey(
            fullName: normalized.fullName,
            firstName: draft.prenom,
            lastName: draft.nomDeFamille,
            email: normalizedEmail
        )

        if let index = resources.firstIndex(where: {
            resourceMatchingKey(
                fullName: $0.fullName,
                firstName: nil,
                lastName: nil,
                email: cleanedOptionalString($0.email)
            ) == normalizedKey
        }) {
            let existingResource = resources[index]
            let updateResult = mergeExistingResource(
                existingResource,
                draft: draft,
                normalized: normalized,
                trimmedNotes: trimmedNotes,
                normalizedEmail: normalizedEmail,
                normalizedPhone: normalizedPhone
            )

            return ResourceImportReviewItem(
                sourceRowNumber: draft.sourceRowNumber,
                action: updateResult.changes.isEmpty ? .noChange : .update,
                resourceID: existingResource.id,
                displayName: existingResource.displayName,
                changes: updateResult.changes,
                proposedResource: updateResult.mergedResource,
                isExistingResource: true
            )
        }

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
            email: normalizedEmail ?? "",
            phone: normalizedPhone ?? "",
            engagement: normalized.engagement,
            status: normalized.status,
            allocationPercent: normalized.allocationPercent,
            assignedProjectIDs: [],
            notes: trimmedNotes
        )

        return ResourceImportReviewItem(
            sourceRowNumber: draft.sourceRowNumber,
            action: .create,
            resourceID: createdResource.id,
            displayName: createdResource.displayName,
            changes: creationFieldChanges(for: createdResource),
            proposedResource: createdResource,
            isExistingResource: false
        )
    }

    func mergeExistingResource(
        _ existingResource: Resource,
        draft: ResourceImportDraft,
        normalized: NormalizedResourceFieldsStore,
        trimmedNotes: String,
        normalizedEmail: String?,
        normalizedPhone: String?
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
        applyStringValue(normalizedEmail, label: "E-mail", keyPath: \.email)
        applyStringValue(normalizedPhone, label: "Téléphone", keyPath: \.phone)

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

    func creationFieldChanges(for resource: Resource) -> [ResourceImportFieldChange] {
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

    func resourceMatchingKey(fullName: String, firstName: String?, lastName: String?, email: String?) -> String {
        if let normalizedEmail = cleanedOptionalString(email)?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           normalizedEmail.isEmpty == false {
            return "email|\(normalizedEmail)"
        }

        let identityPair = explicitNamePair(
            fullName: fullName,
            firstName: cleanedOptionalString(firstName),
            lastName: cleanedOptionalString(lastName)
        )

        return "name|\(identityPair.first)|\(identityPair.last)"
    }

    func explicitNamePair(fullName: String, firstName: String?, lastName: String?) -> (first: String, last: String) {
        let normalizedFirstName = normalizedNameToken(firstName)
        let normalizedLastName = normalizedNameToken(lastName)

        if normalizedFirstName.isEmpty == false || normalizedLastName.isEmpty == false {
            return (normalizedFirstName, normalizedLastName)
        }

        let tokens = fullName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard tokens.isEmpty == false else { return ("", "") }
        if tokens.count == 1 {
            return ("", tokens[0])
        }

        return (tokens.dropLast().joined(separator: " "), tokens.last ?? "")
    }

    func normalizedNameToken(_ value: String?) -> String {
        value?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
