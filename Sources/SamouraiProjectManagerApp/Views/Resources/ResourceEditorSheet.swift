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
        _notes = State(initialValue: resource?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Colonnes source") {
                    TextField("Nom", text: $nom)
                    TextField("Parent Description", text: $parentDescription)
                    TextField("Primary Resource Role", text: $primaryResourceRole)
                    TextField("Resource Roles", text: $resourceRoles)
                    TextField("Organizational Resource", text: $organizationalResource)
                    TextField("Compétence 1", text: $competence1)
                    TextField("Resource Calendar", text: $resourceCalendar)

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

                    TextField("Responsable Opérationnel", text: $responsableOperationnel)
                    TextField("Responsable Interne", text: $responsableInterne)
                    TextField("Localisation", text: $localisation)
                    TextField("Type de Ressource", text: $typeDeRessource)
                    TextField("Journée(s) temps partiel", text: $journeesTempsPartiel)
                }

                Section("Application") {
                    TextField("E-mail", text: $email)
                    TextField("Téléphone", text: $phone)
                }

                Section("Projets affectés") {
                    if store.projects.isEmpty {
                        Text("Aucun projet disponible")
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
                        Text("Aucun Projet Principal défini: affectation manuelle requise.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Projet principal préaffecté automatiquement, modifiable à tout moment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Notes opérationnelles", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(resource == nil ? "Nouvelle ressource" : "Modifier la ressource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
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
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
                Button("Enregistrer") {
                    save()
                }
            }
            Button("Ignorer les modifications", role: .destructive) {
                dismiss()
            }
            Button("Continuer l'édition", role: .cancel) {}
        } message: {
            Text("Les informations déjà saisies peuvent être enregistrées ou abandonnées.")
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
}
