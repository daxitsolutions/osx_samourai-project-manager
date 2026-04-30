import SwiftUI

struct ResourceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let resource: Resource?

    @State private var nom: String
    @State private var parentDescription: String
    @State private var primaryResourceRole: String
    @State private var resourceRoles: String
    @State private var organizationalResource: String
    @State private var competence1: String
    @State private var resourceCalendar: String
    @State private var resourceStartDate: Date?
    @State private var resourceFinishDate: Date?
    @State private var responsableOperationnel: String
    @State private var responsableInterne: String
    @State private var localisation: String
    @State private var typeDeRessource: String
    @State private var journeesTempsPartiel: String
    @State private var email: String
    @State private var phone: String
    @State private var assignedProjectIDs: Set<UUID>
    @State private var notes: String
    @State private var templateResourceID: UUID?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    init(resource: Resource?) {
        self.resource = resource
        _nom = State(initialValue: resource?.nom ?? resource?.fullName ?? "")
        _parentDescription = State(initialValue: resource?.parentDescription ?? resource?.department ?? "")
        _primaryResourceRole = State(initialValue: resource?.primaryResourceRole ?? resource?.jobTitle ?? "")
        _resourceRoles = State(initialValue: resource?.resourceRoles ?? "")
        _organizationalResource = State(initialValue: resource?.organizationalResource ?? "")
        _competence1 = State(initialValue: resource?.competence1 ?? "")
        _resourceCalendar = State(initialValue: resource?.resourceCalendar ?? "")
        _resourceStartDate = State(initialValue: resource?.resourceStartDate)
        _resourceFinishDate = State(initialValue: resource?.resourceFinishDate)
        _responsableOperationnel = State(initialValue: resource?.responsableOperationnel ?? "")
        _responsableInterne = State(initialValue: resource?.responsableInterne ?? "")
        _localisation = State(initialValue: resource?.localisation ?? "")
        _typeDeRessource = State(initialValue: resource?.typeDeRessource ?? "")
        _journeesTempsPartiel = State(initialValue: resource?.journeesTempsPartiel ?? "")
        _email = State(initialValue: resource?.email ?? "")
        _phone = State(initialValue: resource?.phone ?? "")
        _assignedProjectIDs = State(initialValue: Set(resource?.assignedProjectIDs ?? []))
        _templateResourceID = State(initialValue: resource?.templateResourceID)
        _notes = State(initialValue: resource?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Colonnes source")) {
                    TextField(localized("Nom"), text: $nom)
                    TextField(localized("Parent Description"), text: $parentDescription)
                    TextField(localized("Primary Resource Role"), text: $primaryResourceRole)
                    TextField(localized("Resource Roles"), text: $resourceRoles)
                    TextField(localized("Organizational Resource"), text: $organizationalResource)
                    TextField(localized("Compétence 1"), text: $competence1)
                    TextField(localized("Resource Calendar"), text: $resourceCalendar)

                    DatePicker(
                        "Resource Start Date",
                        selection: optionalDateBinding($resourceStartDate),
                        displayedComponents: .date
                    )

                    DatePicker(
                        "Resource Finish Date",
                        selection: optionalDateBinding($resourceFinishDate),
                        displayedComponents: .date
                    )

                    TextField(localized("Responsable Opérationnel"), text: $responsableOperationnel)
                    TextField(localized("Responsable Interne"), text: $responsableInterne)
                    TextField(localized("Localisation"), text: $localisation)
                    TextField(localized("Type de Ressource"), text: $typeDeRessource)
                    TextField(localized("Journée(s) temps partiel"), text: $journeesTempsPartiel)
                }

                Section(localized("Application")) {
                    TextField(localized("E-mail"), text: $email)
                    TextField(localized("Téléphone"), text: $phone)
                }

                Section(localized("Projets affectés")) {
                    if store.projects.isEmpty {
                        Text(localized("Aucun projet disponible"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.projects) { project in
                            Toggle(
                                project.name,
                                isOn: Binding(
                                    get: { assignedProjectIDs.contains(project.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            assignedProjectIDs.insert(project.id)
                                        } else {
                                            assignedProjectIDs.remove(project.id)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }

                    if appState.resolvedPrimaryProjectID(in: store) == nil {
                        Text(localized("Aucun Projet Principal défini: affectation manuelle requise."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(localized("Projet principal préaffecté automatiquement, modifiable à tout moment."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if assignedProjectIDs.isEmpty == false {
                    Section(localized("Ressource template")) {
                        let candidates = store.resources.filter { $0.id != resource?.id && $0.assignedProjectIDs.isEmpty }
                        if candidates.isEmpty {
                            Text(localized("Aucune ressource template disponible dans l'annuaire global."))
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        } else {
                            Picker(localized("Template associé"), selection: $templateResourceID) {
                                Text(localized("Aucun")).tag(UUID?.none)
                                ForEach(candidates) { candidate in
                                    Text(candidate.displayName).tag(UUID?.some(candidate.id))
                                }
                            }
                            .pickerStyle(.menu)
                            if let tid = templateResourceID, let t = store.resource(with: tid) {
                                Text(localized("Rôle : \(t.displayPrimaryRole)") + " • " + localized("Dép. : \(t.displayDepartment)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(localized("Lie cette ressource de projet à un modèle de l'annuaire global (1 template → N ressources de projet)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(localized("Notes")) {
                    TextField(localized("Notes opérationnelles"), text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(resource == nil ? "Nouvelle ressource" : "Modifier la ressource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(resource == nil ? "Créer" : "Enregistrer") {
                        save()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
                Button(localized("Enregistrer")) {
                    save()
                }
            }
            Button(localized("Ignorer les modifications"), role: .destructive) {
                dismiss()
            }
            Button(localized("Continuer l'édition"), role: .cancel) {}
        } message: {
            Text(localized("Les informations déjà saisies peuvent être enregistrées ou abandonnées."))
        }
        .onAppear {
            applyPrimaryProjectDefaultIfNeeded()
            captureInitialSnapshotIfNeeded()
        }
    }

    private var formIsInvalid: Bool {
        nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var snapshot: String {
        [
            nom,
            parentDescription,
            primaryResourceRole,
            resourceRoles,
            organizationalResource,
            competence1,
            resourceCalendar,
            resourceStartDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            resourceFinishDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            responsableOperationnel,
            responsableInterne,
            localisation,
            typeDeRessource,
            journeesTempsPartiel,
            email,
            phone,
            assignedProjectIDs.map(\.uuidString).sorted().joined(separator: ","),
            templateResourceID?.uuidString ?? "",
            notes
        ].joined(separator: "|")
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDismissConfirmation = true
        } else {
            dismiss()
        }
    }

    private func captureInitialSnapshotIfNeeded() {
        if initialSnapshot == nil {
            initialSnapshot = snapshot
        }
    }

    private func save() {
        let trimmedNom = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedParentDescription = trimmedOptional(parentDescription)
        let trimmedPrimaryResourceRole = trimmedOptional(primaryResourceRole)
        let trimmedResourceRoles = trimmedOptional(resourceRoles)
        let trimmedOrganizationalResource = trimmedOptional(organizationalResource)
        let trimmedCompetence1 = trimmedOptional(competence1)
        let trimmedResourceCalendar = trimmedOptional(resourceCalendar)
        let trimmedResponsableOperationnel = trimmedOptional(responsableOperationnel)
        let trimmedResponsableInterne = trimmedOptional(responsableInterne)
        let trimmedLocalisation = trimmedOptional(localisation)
        let trimmedTypeDeRessource = trimmedOptional(typeDeRessource)
        let trimmedJourneesTempsPartiel = trimmedOptional(journeesTempsPartiel)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let resource {
            store.updateResource(
                resourceID: resource.id,
                nom: trimmedNom,
                parentDescription: trimmedParentDescription,
                primaryResourceRole: trimmedPrimaryResourceRole,
                resourceRoles: trimmedResourceRoles,
                organizationalResource: trimmedOrganizationalResource,
                competence1: trimmedCompetence1,
                resourceCalendar: trimmedResourceCalendar,
                resourceStartDate: resourceStartDate,
                resourceFinishDate: resourceFinishDate,
                responsableOperationnel: trimmedResponsableOperationnel,
                responsableInterne: trimmedResponsableInterne,
                localisation: trimmedLocalisation,
                typeDeRessource: trimmedTypeDeRessource,
                journeesTempsPartiel: trimmedJourneesTempsPartiel,
                email: trimmedEmail,
                phone: trimmedPhone,
                assignedProjectIDs: normalizedAssignedProjectIDs(),
                notes: trimmedNotes
            )
            applyTemplateLink(resourceID: resource.id)
            appState.selectedResourceID = resource.id
        } else {
            let resourceID = store.addResource(
                nom: trimmedNom,
                parentDescription: trimmedParentDescription,
                primaryResourceRole: trimmedPrimaryResourceRole,
                resourceRoles: trimmedResourceRoles,
                organizationalResource: trimmedOrganizationalResource,
                competence1: trimmedCompetence1,
                resourceCalendar: trimmedResourceCalendar,
                resourceStartDate: resourceStartDate,
                resourceFinishDate: resourceFinishDate,
                responsableOperationnel: trimmedResponsableOperationnel,
                responsableInterne: trimmedResponsableInterne,
                localisation: trimmedLocalisation,
                typeDeRessource: trimmedTypeDeRessource,
                journeesTempsPartiel: trimmedJourneesTempsPartiel,
                email: trimmedEmail,
                phone: trimmedPhone,
                assignedProjectIDs: normalizedAssignedProjectIDs(),
                notes: trimmedNotes
            )
            applyTemplateLink(resourceID: resourceID)
            appState.selectedResourceID = resourceID
        }

        appState.selectedSection = .resources
        dismiss()
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func optionalDateBinding(_ binding: Binding<Date?>) -> Binding<Date> {
        Binding<Date>(
            get: { binding.wrappedValue ?? .now },
            set: { binding.wrappedValue = $0 }
        )
    }

    private func applyTemplateLink(resourceID: UUID) {
        if let tid = templateResourceID {
            store.assignTemplate(resourceID: resourceID, templateID: tid)
        } else {
            store.unassignTemplate(resourceID: resourceID)
        }
    }

    private func normalizedAssignedProjectIDs() -> [UUID] {
        store.projects
            .map(\.id)
            .filter { assignedProjectIDs.contains($0) }
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard resource == nil, assignedProjectIDs.isEmpty else { return }
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            assignedProjectIDs.insert(primaryProjectID)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
