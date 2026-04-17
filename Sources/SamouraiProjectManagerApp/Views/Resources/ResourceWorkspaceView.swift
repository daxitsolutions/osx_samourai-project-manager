import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ResourceWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var editorContext: ResourceEditorContext?
    @State private var resourcePendingDeletion: Resource?
    @State private var isShowingFileImporter = false
    @State private var importFeedbackMessage: String?
    @State private var isImporting = false

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ressources humaines")
                            .font(.title2.weight(.semibold))
                        Text("\(store.resources.count) ressource(s) suivie(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Importer", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)

                    Button {
                        editorContext = .create
                    } label: {
                        Label("Nouvelle", systemImage: "plus")
                    }
                    .disabled(isImporting)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List(store.resources, selection: $appState.selectedResourceID) { resource in
                    ResourceListRow(
                        resource: resource,
                        assignedProjectName: projectName(for: resource.assignedProjectID)
                    )
                    .tag(resource.id)
                    .contextMenu {
                        Button("Modifier") {
                            editorContext = .edit(resource.id)
                        }

                        Button("Supprimer", role: .destructive) {
                            resourcePendingDeletion = resource
                        }
                    }
                }
                .overlay {
                    if store.resources.isEmpty {
                        ContentUnavailableView(
                            "Aucune ressource",
                            systemImage: "person.3",
                            description: Text("Crée les membres de ton dispositif projet pour suivre la capacité réelle.")
                        )
                    }
                }
            }
            .frame(minWidth: 320, idealWidth: 360)

            Group {
                if let selectedResourceID = appState.selectedResourceID,
                   let resource = store.resource(with: selectedResourceID) {
                    ResourceDetailView(
                        resource: resource,
                        assignedProjectName: projectName(for: resource.assignedProjectID),
                        onEdit: {
                            editorContext = .edit(resource.id)
                        },
                        onDelete: {
                            resourcePendingDeletion = resource
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Sélectionne une ressource",
                        systemImage: "person.crop.circle",
                        description: Text("La fiche détail te permettra de suivre capacité, statut et affectation projet.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $editorContext) { context in
            ResourceEditorSheet(resource: context.resource(in: store))
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: SamouraiImportContentTypes.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .alert("Supprimer la ressource", isPresented: Binding(
            get: { resourcePendingDeletion != nil },
            set: { if $0 == false { resourcePendingDeletion = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let resource = resourcePendingDeletion {
                    if appState.selectedResourceID == resource.id {
                        appState.selectedResourceID = nil
                    }
                    store.deleteResource(resourceID: resource.id)
                }
                resourcePendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                resourcePendingDeletion = nil
            }
        } message: {
            Text("Cette action retirera la ressource du référentiel local.")
        }
        .alert("Import des ressources", isPresented: Binding(
            get: { importFeedbackMessage != nil },
            set: { if $0 == false { importFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importFeedbackMessage ?? "")
        }
    }

    private func projectName(for projectID: UUID?) -> String? {
        guard let projectID else { return nil }
        return store.project(with: projectID)?.name
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else {
            if case .failure(let error) = result {
                importFeedbackMessage = error.localizedDescription
            }
            return
        }

        isImporting = true
        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()

        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
            isImporting = false
        }

        do {
            let drafts = try ResourceImportService.importResources(from: fileURL)
            let importResult = store.importResources(drafts)

            if let resourceID = importResult.firstImportedOrUpdatedResourceID {
                appState.selectedResourceID = resourceID
                appState.selectedSection = .resources
            }

            importFeedbackMessage = "Import terminé : \(importResult.summary)"
        } catch {
            importFeedbackMessage = error.localizedDescription
        }
    }
}

private enum SamouraiImportContentTypes {
    static let allowedTypes: [UTType] = [
        UTType(filenameExtension: "xlsx") ?? .data,
        .commaSeparatedText,
        .tabSeparatedText
    ]
}

private enum ResourceEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let id):
            "edit-\(id.uuidString)"
        }
    }

    @MainActor
    func resource(in store: SamouraiStore) -> Resource? {
        switch self {
        case .create:
            nil
        case .edit(let id):
            store.resource(with: id)
        }
    }
}

private struct ResourceListRow: View {
    let resource: Resource
    let assignedProjectName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(resource.displayName)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(Color(resource.status.tintName))
                    .frame(width: 10, height: 10)
            }

            Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                .foregroundStyle(.secondary)

            HStack {
                Text(resource.allocationLabel)
                Spacer()
                Text(assignedProjectName ?? "Non affecté")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct ResourceDetailView: View {
    let resource: Resource
    let assignedProjectName: String?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(resource.displayName)
                                .font(.largeTitle.weight(.semibold))
                            Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack {
                            Button("Modifier", action: onEdit)
                            Button("Supprimer", role: .destructive, action: onDelete)
                        }
                    }

                    HStack(spacing: 18) {
                        Label(resource.displayDepartment.isEmpty ? "Non renseigné" : resource.displayDepartment, systemImage: "building.2")
                        Label(resource.engagement.label, systemImage: "person.badge.key")
                        Label(resource.status.label, systemImage: "checkmark.seal")
                        Label(resource.allocationLabel, systemImage: "chart.bar")
                    }
                    .foregroundStyle(.secondary)
                }

                Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                    GridRow {
                        detailCard(title: "Projet affecté", value: assignedProjectName ?? "Aucun")
                        detailCard(title: "E-mail", value: resource.email.isEmpty ? "-" : resource.email)
                        detailCard(title: "Téléphone", value: resource.phone.isEmpty ? "-" : resource.phone)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Attributs importés")
                        .font(.title2.weight(.semibold))

                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            detailCard(title: "Nom", value: resource.nom ?? "-")
                            detailCard(title: "Parent Description", value: resource.parentDescription ?? "-")
                            detailCard(title: "Primary Resource Role", value: resource.primaryResourceRole ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Resource Roles", value: resource.resourceRoles ?? "-")
                            detailCard(title: "Organizational Resource", value: resource.organizationalResource ?? "-")
                            detailCard(title: "Compétence 1", value: resource.competence1 ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Resource Calendar", value: resource.resourceCalendar ?? "-")
                            detailCard(title: "Resource Start Date", value: formattedDate(resource.resourceStartDate))
                            detailCard(title: "Resource Finish Date", value: formattedDate(resource.resourceFinishDate))
                        }

                        GridRow {
                            detailCard(title: "Responsable Opérationnel", value: resource.responsableOperationnel ?? "-")
                            detailCard(title: "Responsable Interne", value: resource.responsableInterne ?? "-")
                            detailCard(title: "Localisation", value: resource.localisation ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Type de Ressource", value: resource.typeDeRessource ?? "-")
                            detailCard(title: "Journée(s) temps partiel", value: resource.journeesTempsPartiel ?? "-")
                            detailCard(title: "Allocation normalisée", value: resource.allocationLabel)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes opérationnelles")
                        .font(.title2.weight(.semibold))

                    Text(resource.notes.isEmpty ? "Aucune note renseignée." : resource.notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

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
    @State private var assignedProjectID: UUID?
    @State private var notes: String

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
        _assignedProjectID = State(initialValue: resource?.assignedProjectID)
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
                Picker("Projet affecté", selection: $assignedProjectID) {
                    Text("Non affecté").tag(nil as UUID?)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
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
                        dismiss()
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
    }

    private var formIsInvalid: Bool {
        nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                assignedProjectID: assignedProjectID,
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
                assignedProjectID: assignedProjectID,
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
}
