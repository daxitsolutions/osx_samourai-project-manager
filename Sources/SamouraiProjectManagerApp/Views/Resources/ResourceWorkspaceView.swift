import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ResourceWorkspaceScopeMode {
    case contextualProject
    case globalDirectory
}

struct ResourceWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let scopeMode: ResourceWorkspaceScopeMode

    @AppStorage("resources.displayMode") private var displayModeRawValue = ResourceDisplayMode.grid.rawValue

    @State private var isImporting = false
    @State private var exportDocument: ResourceExportDocument?
    @State private var exportFilename = "ressources"
    @State private var presentation = ResourceWorkspacePresentationState()
    @State private var searchText = ""
    @State private var searchCache = ResourceSearchCache()
    @State private var selectedResourceIDs: Set<UUID> = []
    @State private var importReviewItems: [ResourceImportReviewDecision] = []
    @State private var activeImportTask: Task<Void, Never>?
    @State private var inlineDrafts: [UUID: ResourceInlineDraft] = [:]
    @State private var projectFavoriteFilter: ResourceProjectFavoriteFilter = .all
    @State private var sortOrder: [KeyPathComparator<Resource>] = [
        .init(\.fullName, order: .reverse)
    ]
    @State private var columnCustomization = TableColumnCustomization<Resource>()
    @FocusState private var focusedInlineCell: ResourceInlineCellKey?

    init(scopeMode: ResourceWorkspaceScopeMode = .contextualProject) {
        self.scopeMode = scopeMode
    }

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 420, sidebarIdealWidth: 560, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspaceTitle)
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d ressource(s) affichée(s)", filteredResources.count, searchBaseResources.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if scopeMode == .globalDirectory {
                        Toggle(isOn: Binding(
                            get: { allFilteredResourcesSelected },
                            set: { _ in toggleSelectAllFilteredResources() }
                        )) {
                            Text(appState.localizedFormat("Tout sélectionner (%d)", filteredResources.count))
                        }
                        .toggleStyle(.checkbox)
                        .disabled(isImporting || filteredResources.isEmpty)
                    }

                    if let selectedResource = selectedResource {
                        if canAssignSelectedResourceToScopedProject {
                            Button {
                                assignSelectedResourceToScopedProject()
                            } label: {
                                Label(localized("Ajouter au projet"), systemImage: "plus.circle")
                            }
                            .disabled(isImporting)
                        } else if canRemoveSelectedResourceFromScopedProject {
                            Button {
                                presentation.show(.removeFromProject(selectedResource))
                            } label: {
                                Label(localized("Retirer du projet"), systemImage: "minus.circle")
                            }
                            .disabled(isImporting)
                        }

                        if scopeMode == .contextualProject {
                            Button {
                                presentation.show(.memo(selectedResource.id))
                            } label: {
                                Label(localized("Mémo"), systemImage: "doc.text.magnifyingglass")
                            }
                            .disabled(isImporting)

                            Button {
                                presentation.show(.evaluation(selectedResource.id))
                            } label: {
                                Label(localized("Évaluer"), systemImage: "waveform.path.ecg.rectangle")
                            }
                            .disabled(isImporting)
                        }

                        if scopeMode == .globalDirectory {
                            Button {
                                presentation.show(.templates(selectedResource.id))
                            } label: {
                                Label(localized("Ressources liées"), systemImage: "doc.on.doc")
                            }
                            .disabled(isImporting)
                        }
                    }

                    if !resourceDeletionTargets.isEmpty {
                        Button {
                            if let id = resourceEditTargetID { presentation.show(.edit(id)) }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(isImporting || resourceEditTargetID == nil)

                        Button(role: .destructive) {
                            let targets = resourceDeletionTargets
                            presentation.show(.delete(targets))
                        } label: {
                            Label(localized("Supprimer"), systemImage: "trash")
                        }
                        .disabled(isImporting)
                    }

                    Menu {
                        Button(localized("Exporter toutes les ressources")) {
                            prepareExport(
                                resources: scopedResources,
                                defaultFilename: "ressources-\(Date.now.formatted(.dateTime.year().month().day()))"
                            )
                        }

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedResourcesForExport.count)) {
                            prepareExport(
                                resources: selectedResourcesForExport,
                                defaultFilename: "ressources-selection-\(Date.now.formatted(.dateTime.year().month().day()))"
                            )
                        }
                        .disabled(selectedResourcesForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(isImporting || scopedResources.isEmpty)

                    if scopeMode == .globalDirectory {
                        Button {
                            presentation.show(.importFile)
                        } label: {
                            Label(localized("Importer"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(isImporting)

                        Button {
                            presentation.show(.create)
                        } label: {
                            Label(localized("Nouvelle"), systemImage: "plus")
                        }
                        .disabled(isImporting)
                    } else if scopedProjectID != nil {
                        Button {
                            presentation.show(.directory)
                        } label: {
                            Label(localized("Ajouter depuis l'annuaire"), systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                VStack(spacing: 12) {
                    if scopeMode == .contextualProject {
                        ResourceProfilingSummaryCard(
                            report: resourceProfilingReport,
                            scopeLabel: resourceProfilingScopeLabel
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        ResourceComparativePerformanceCard(
                            snapshots: comparativePerformanceSnapshots,
                            onEvaluate: { resourceID in
                                presentation.show(.evaluation(resourceID))
                            }
                        )
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        TextField(
                            scopedProjectID == nil ? "Rechercher dans l'annuaire" : "Rechercher dans l'annuaire global et le projet",
                            text: $searchText
                        )
                            .textFieldStyle(.roundedBorder)

                        if scopedProjectID != nil {
                            Picker(localized("Favoris"), selection: $projectFavoriteFilter) {
                                ForEach(ResourceProjectFavoriteFilter.allCases) { filter in
                                    Text(filter.label.appLocalized(language: appState.interfaceLanguage)).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }

                        Picker(localized("Affichage"), selection: displayModeBinding) {
                            ForEach(ResourceDisplayMode.allCases) { mode in
                                Label(mode.label.appLocalized(language: appState.interfaceLanguage), systemImage: mode.iconName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)

                        Button {
                            appState.selectedSection = .configuration
                        } label: {
                            Label(localized("Colonnes"), systemImage: "slider.horizontal.3")
                        }
                        .help(localized("Configurer les colonnes dans le volet Configuration"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                    if let assignmentContextNote {
                        Text(assignmentContextNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }

                    resourceCollectionView(selectedResourceID: $appState.selectedResourceID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .overlay {
                    if searchBaseResources.isEmpty {
                        ContentUnavailableView(
                            "Aucune ressource",
                            systemImage: "person.3",
                            description: Text(emptyStateDescription)
                        )
                    } else if filteredResources.isEmpty {
                        ContentUnavailableView(
                            "Aucun résultat",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text(localized("Ajuste la recherche pour retrouver une ressource de l'annuaire ou l'ajouter au projet en cours."))
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .frame(minWidth: 420, idealWidth: 560)

        } detail: {
            EmptyView()
        }
        .sheet(item: sheetPresentation) { item in
            resourceSheet(item.destination)
        }
        .fileImporter(
            isPresented: presentationBinding(for: .importFile),
            allowedContentTypes: SamouraiImportContentTypes.allowedTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .fileExporter(
            isPresented: presentationBinding(for: .exportFile),
            document: exportDocument,
            contentType: SamouraiExportContentTypes.xlsx,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                showFeedback("Export des ressources", "Export terminé avec succès.")
            case .failure(let error):
                showFeedback("Export des ressources", error.localizedDescription)
            }
        }
        .alert(alertTitle, isPresented: presentationBinding(for: .alert), presenting: presentation.current) { item in
            resourceAlertActions(item)
        } message: { item in
            Text(alertMessage(item.destination))
        }
        .onAppear { presentation.activate() }
        .onDisappear {
            presentation.deactivate()
            cancelActiveImport()
            importReviewItems = []
        }
        .onChange(of: store.resources.map(\.id)) { _, currentResourceIDs in
            let existingIDs = Set(currentResourceIDs)
            selectedResourceIDs = selectedResourceIDs.intersection(existingIDs)
            inlineDrafts = inlineDrafts.filter { existingIDs.contains($0.key) }

            if let selectedResourceID = appState.selectedResourceID, existingIDs.contains(selectedResourceID) == false {
                appState.selectedResourceID = nil
            }
        }
    }

    private var sheetPresentation: Binding<ResourceWorkspacePresentation?> {
        let shown = presentation.presented(for: .sheet)
        return Binding(
            get: { presentation.presented(for: .sheet) },
            set: { value in
                guard value == nil, let shown, presentation.current?.id == shown.id else { return }
                if case .review = shown.destination { importReviewItems = [] }
                presentation.dismiss(id: shown.id)
            }
        )
    }

    private func presentationBinding(for kind: ResourceWorkspacePresentation.Kind) -> Binding<Bool> {
        let shown = presentation.presented(for: kind)
        return Binding(
            get: { presentation.presented(for: kind) != nil },
            set: { isPresented in
                if !isPresented, let shown, shown.kind == kind { presentation.dismiss(id: shown.id) }
            }
        )
    }

    private func showFeedback(_ title: String, _ message: String) {
        presentation.show(.feedback(title: title, message: message))
    }

    @ViewBuilder
    private func resourceSheet(_ destination: ResourceWorkspacePresentation.Destination) -> some View {
        switch destination {
        case .create:
            ResourceEditorSheet(resource: nil)
        case .edit(let id):
            ResourceEditorSheet(resource: store.resource(with: id))
        case .evaluation(let id):
            if let resource = store.resource(with: id) {
                ResourceEvaluationSheet(
                    resource: resource,
                    scopedProject: scopedProjectID.flatMap { store.project(with: $0) },
                    onSave: { payload in
                        store.addResourceEvaluation(
                            resourceID: resource.id,
                            projectID: scopedProjectID,
                            milestone: payload.milestone,
                            evaluator: payload.evaluator,
                            comment: payload.comment,
                            criterionScores: payload.criterionScores,
                            evaluatedAt: payload.evaluatedAt
                        )
                        showFeedback("Évaluation des ressources", "Évaluation enregistrée pour \(resource.displayName).")
                    }
                )
            } else {
                Text(localized("Ressource introuvable.")).padding(24)
            }
        case .directory:
            if let projectID = scopedProjectID {
                ResourceDirectoryPickerSheet(projectID: projectID, projectName: scopedProjectName ?? "")
            }
        case .memo(let id):
            if let resource = store.resource(with: id) {
                ResourceMemoPreviewSheet(resource: resource)
            } else {
                Text(localized("Ressource introuvable.")).padding(24)
            }
        case .templates(let id):
            if let template = store.resource(with: id) {
                ResourceTemplateManagementSheet(
                    template: template,
                    onLink: { store.assignTemplate(resourceID: $0, templateID: id) },
                    onUnlink: { store.unassignTemplate(resourceID: $0) }
                )
            }
        case .review:
            ResourceImportReviewSheet(
                decisions: $importReviewItems,
                onCancel: {
                    importReviewItems = []
                    presentation.dismissAll()
                },
                onApply: applyImportReview
            )
        default:
            EmptyView()
        }
    }

    private var alertTitle: String {
        guard let destination = presentation.current?.destination else { return "" }
        switch destination {
        case .delete(let resources):
            return localized(resources.count <= 1 ? "Supprimer la ressource" : "Supprimer les ressources")
        case .removeFromProject:
            return localized("Retirer la ressource du projet")
        case .confirmImport:
            return localized("Confirmer l'import")
        case .feedback(let title, _):
            return localized(title)
        default:
            return ""
        }
    }

    private func alertMessage(_ destination: ResourceWorkspacePresentation.Destination) -> String {
        switch destination {
        case .delete(let resources):
            return resources.count <= 1
                ? localized("Cette action retirera la ressource du référentiel local.")
                : appState.localizedFormat("Voulez-vous vraiment supprimer %d ressources du référentiel local ?", resources.count)
        case .removeFromProject(let resource):
            return projectRemovalConfirmationMessage(for: resource)
        case .confirmImport(let drafts):
            return String(format: AppLocalizer.localized("%d ligne(s) détectée(s). Le traitement s'effectuera par lots de 10 lignes. Confirmer l'import ?"), drafts.count)
        case .feedback(_, let message):
            return message
        default:
            return ""
        }
    }

    @ViewBuilder
    private func resourceAlertActions(_ item: ResourceWorkspacePresentation) -> some View {
        switch item.destination {
        case .delete(let resources):
            Button(localized("Supprimer"), role: .destructive) {
                deleteResources(resources)
                presentation.dismiss(id: item.id)
            }
            Button(localized("Annuler"), role: .cancel) { presentation.dismiss(id: item.id) }
        case .removeFromProject(let resource):
            Button(localized("Oui"), role: .destructive) {
                removeResourceFromScopedProject(resource.id)
                presentation.dismiss(id: item.id)
            }
            Button(localized("Non"), role: .cancel) { presentation.dismiss(id: item.id) }
        case .confirmImport(let drafts):
            Button(localized("Importer")) { proceedWithPendingImport(drafts) }
            Button(localized("Annuler"), role: .cancel) { cancelActiveImport() }
        default:
            Button(localized("OK"), role: .cancel) { presentation.dismiss(id: item.id) }
        }
    }

    private var selectedResource: Resource? {
        guard let selectedResourceID = appState.selectedResourceID else { return nil }
        return store.resource(with: selectedResourceID)
    }

    private var selectedResourcesForExport: [Resource] {
        scopedResources.filter { selectedResourceIDs.contains($0.id) }
    }

    private var allFilteredResourcesSelected: Bool {
        filteredResources.isEmpty == false
            && filteredResources.allSatisfy { selectedResourceIDs.contains($0.id) }
    }

    private func toggleSelectAllFilteredResources() {
        let ids = filteredResources.map(\.id)
        if allFilteredResourcesSelected {
            selectedResourceIDs.subtract(ids)
        } else {
            selectedResourceIDs.formUnion(ids)
        }
    }

    // Cibles d'action : la sélection multiple (cases à cocher) prime, sinon la ligne active.
    private var resourceDeletionTargets: [Resource] {
        if selectedResourceIDs.isEmpty == false {
            return scopedResources.filter { selectedResourceIDs.contains($0.id) }
        }
        return selectedResource.map { [$0] } ?? []
    }

    // « Modifier » n'est actif que pour une seule ressource.
    private var resourceEditTargetID: UUID? {
        if selectedResourceIDs.count == 1 { return selectedResourceIDs.first }
        if selectedResourceIDs.isEmpty { return appState.selectedResourceID }
        return nil
    }

    private func deleteResources(_ resources: [Resource]) {
        for resource in resources {
            if appState.selectedResourceID == resource.id { appState.selectedResourceID = nil }
            selectedResourceIDs.remove(resource.id)
            store.deleteResource(resourceID: resource.id)
        }
    }

    private var scopedProjectID: UUID? {
        switch scopeMode {
        case .contextualProject:
            appState.resolvedPrimaryProjectID(in: store)
        case .globalDirectory:
            nil
        }
    }

    private var scopedProjectName: String? {
        scopedProjectID.flatMap { store.project(with: $0)?.name }
    }

    private var workspaceTitle: String {
        switch scopeMode {
        case .globalDirectory:
            return "Annuaire des ressources"
        case .contextualProject:
            if let scopedProjectName {
                return "Ressources — \(scopedProjectName)"
            }
            return "Ressources du projet"
        }
    }

    private var resourceProfilingReport: ResourceProfilingReport {
        store.resourceProfiling(for: scopedProjectID)
    }

    private var resourceProfilingScopeLabel: String {
        if let scopedProjectID, let project = store.project(with: scopedProjectID) {
            return "Portée: \(project.name)"
        }
        return "Portée: Tous les projets"
    }

    private var comparativePerformanceSnapshots: [ResourcePerformanceSnapshot] {
        store.comparativePerformance(for: scopedProjectID)
    }

    private var displayModeBinding: Binding<ResourceDisplayMode> {
        Binding(
            get: { ResourceDisplayMode(rawValue: displayModeRawValue) ?? .grid },
            set: { displayModeRawValue = $0.rawValue }
        )
    }

    private var visibleTableColumns: Set<ResourceTableColumn> {
        Set(
            appState
                .visibleTableColumnIDs(for: .resources)
                .compactMap(ResourceTableColumn.init(rawValue:))
        )
    }

    private func isColumnVisible(_ column: ResourceTableColumn) -> Bool {
        visibleTableColumns.contains(column)
    }

    private var activeTableColumns: [ResourceTableColumn] {
        appState
            .orderedVisibleTableColumnIDs(for: .resources)
            .compactMap(ResourceTableColumn.init(rawValue:))
    }

    private var searchBaseResources: [Resource] {
        scopedResources
    }

    private var filteredResources: [Resource] {
        searchCache.results(
            resources: store.resources,
            projectNames: Dictionary(uniqueKeysWithValues: store.projects.map { ($0.id, $0.name) }),
            query: searchText,
            projectID: scopedProjectID,
            favoritesOnly: projectFavoriteFilter == .favoritesOnly,
            sortOrder: sortOrder,
            language: appState.interfaceLanguage
        )
    }

    private var scopedResources: [Resource] {
        if let primaryProjectID = scopedProjectID {
            return store.resources.filter { $0.assignedProjectIDs.contains(primaryProjectID) }
        }
        return store.resources
    }

    private var assignmentContextNote: String? {
        guard let scopedProjectName else { return nil }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Affichage centré sur les ressources affectées à \(scopedProjectName). Utilise « Ajouter depuis l'annuaire » pour sélectionner une ressource existante du référentiel global."
        }
        return "Recherche annuaire globale active pour \(scopedProjectName). Les ressources non encore affectées peuvent être ajoutées directement au projet."
    }

    private var emptyStateDescription: String {
        switch scopeMode {
        case .globalDirectory:
            return "Importe ou crée les ressources du référentiel pour les réutiliser dans les projets."
        case .contextualProject:
            return "Aucune ressource n'est encore affectée à ce projet. Utilise « Ajouter depuis l'annuaire » pour sélectionner une ressource existante du référentiel global."
        }
    }

    private var canAssignSelectedResourceToScopedProject: Bool {
        guard let selectedResource else { return false }
        return canAssignResource(selectedResource)
    }

    private var canRemoveSelectedResourceFromScopedProject: Bool {
        guard let selectedResource else { return false }
        return canRemoveResource(selectedResource)
    }

    @ViewBuilder
    private func resourceCollectionView(selectedResourceID: Binding<UUID?>) -> some View {
        switch ResourceDisplayMode(rawValue: displayModeRawValue) ?? .grid {
        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(filteredResources) { resource in
                        ResourceGridCard(
                            resource: resource,
                            assignedProjectNames: projectNames(for: resource.assignedProjectIDs),
                            scopedProjectID: scopedProjectID,
                            isSelected: selectedResourceID.wrappedValue == resource.id,
                            isMarkedForExport: selectedResourceIDs.contains(resource.id),
                            templateName: resource.templateResourceID.flatMap { store.resource(with: $0)?.displayName },
                            linkedProjectResourceCount: store.projectResourcesLinkedToTemplate(resource.id).count,
                            onToggleExportSelection: {
                                toggleResourceSelectionForExport(resource.id)
                            },
                            onToggleFavorite: canToggleFavorite(resource)
                                ? ({ toggleFavoriteForScopedProject(resource.id) })
                                : nil,
                            onShowMemo: { presentation.show(.memo(resource.id)) },
                            onEdit: { presentation.show(.edit(resource.id)) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResourceID.wrappedValue = resource.id
                        }
                        .contextMenu {
                            Button(localized("Modifier")) {
                                presentation.show(.edit(resource.id))
                            }

                            Button(localized("Consulter le mémo")) {
                                presentation.show(.memo(resource.id))
                            }

                            Button(localized("Supprimer"), role: .destructive) {
                                presentation.show(.delete([resource]))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.visible)
        case .table:
            VStack(alignment: .leading, spacing: 6) {
                Table(filteredResources, selection: selectedResourceID, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
                    TableColumn("") { resource in
                        HStack(spacing: 8) {
                            Button {
                                toggleResourceSelectionForExport(resource.id)
                            } label: {
                                Image(systemName: selectedResourceIDs.contains(resource.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedResourceIDs.contains(resource.id) ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)

                            if let scopedProjectID, resource.assignedProjectIDs.contains(scopedProjectID) {
                                Button {
                                    toggleFavoriteForScopedProject(resource.id)
                                } label: {
                                    Image(systemName: resource.isFavorite(in: scopedProjectID) ? "star.fill" : "star")
                                        .foregroundStyle(resource.isFavorite(in: scopedProjectID) ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .width(68)

                    TableColumnForEach(activeTableColumns) { column in
                        switch column {
                        case .name:
                            TableColumn(appState.localized(column.label), value: \.fullName) { (resource: Resource) in
                                TextField(
                                    "Nom",
                                    text: inlineTextBinding(for: resource, field: \.nom)
                                )
                                .textFieldStyle(.plain)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .name))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .name)
                                }
                            }
                            .width(min: 160, ideal: 220)
                            .customizationID(column.id)

                        case .primaryResourceRole:
                            TableColumn(appState.localized(column.label), value: \.primaryResourceRoleSortKey) { (resource: Resource) in
                                TextField(
                                    "Rôle",
                                    text: inlineTextBinding(for: resource, field: \.primaryResourceRole)
                                )
                                .textFieldStyle(.plain)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .role))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .role)
                                }
                            }
                            .width(min: 150, ideal: 200)
                            .customizationID(column.id)

                        case .parentDescription:
                            TableColumn(appState.localized(column.label), value: \.parentDescriptionSortKey) { (resource: Resource) in
                                TextField(
                                    "Département",
                                    text: inlineTextBinding(for: resource, field: \.parentDescription)
                                )
                                .textFieldStyle(.plain)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .department))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .department)
                                }
                            }
                            .width(min: 130, ideal: 180)
                            .customizationID(column.id)

                        case .projects:
                            TableColumn(appState.localized(column.label), value: \.assignedProjectCount) { (resource: Resource) in
                                let assignedProjectNames = projectNames(for: resource.assignedProjectIDs)
                                Text(assignedProjectNames.isEmpty ? "-" : assignedProjectNames.joined(separator: ", "))
                            }
                            .width(min: 180, ideal: 260)
                            .customizationID(column.id)

                        case .allocationPercent:
                            TableColumn(appState.localized(column.label), value: \.allocationPercent) { (resource: Resource) in
                                TextField(
                                    "Allocation",
                                    text: inlineTextBinding(for: resource, field: \.allocationPercentText)
                                )
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .allocation))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .allocation)
                                }
                            }
                            .width(min: 70, ideal: 90)
                            .customizationID(column.id)

                        case .status:
                            TableColumn(appState.localized(column.label), value: \.statusSortKey) { (resource: Resource) in
                                Picker(
                                    "Statut",
                                    selection: inlineStatusBinding(for: resource)
                                ) {
                                    ForEach(ResourceStatus.allCases) { status in
                                        Text(status.label.appLocalized(language: appState.interfaceLanguage)).tag(status)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .width(min: 100, ideal: 130)
                            .customizationID(column.id)

                        case .engagement:
                            TableColumn(appState.localized(column.label), value: \.engagementSortKey) { (resource: Resource) in
                                Picker(
                                    "Engagement",
                                    selection: inlineEngagementBinding(for: resource)
                                ) {
                                    ForEach(ResourceEngagement.allCases) { engagement in
                                        Text(engagement.label.appLocalized(language: appState.interfaceLanguage)).tag(engagement)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .width(min: 100, ideal: 140)
                            .customizationID(column.id)

                        case .email:
                            TableColumn(appState.localized(column.label), value: \.email) { (resource: Resource) in
                                TextField(
                                    "E-mail",
                                    text: inlineTextBinding(for: resource, field: \.email)
                                )
                                .textFieldStyle(.plain)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .email))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .email)
                                }
                            }
                            .width(min: 180, ideal: 240)
                            .customizationID(column.id)

                        case .phone:
                            TableColumn(appState.localized(column.label), value: \.phone) { (resource: Resource) in
                                TextField(
                                    "Téléphone",
                                    text: inlineTextBinding(for: resource, field: \.phone)
                                )
                                .textFieldStyle(.plain)
                                .focused($focusedInlineCell, equals: .init(resourceID: resource.id, column: .phone))
                                .onSubmit {
                                    handleInlineSubmit(resourceID: resource.id, column: .phone)
                                }
                            }
                            .width(min: 120, ideal: 160)
                            .customizationID(column.id)

                        case .resourceRoles:
                            TableColumn(appState.localized(column.label), value: \.resourceRolesSortKey) { (resource: Resource) in
                                Text(resource.resourceRoles ?? "-")
                            }
                            .width(min: 140, ideal: 190)
                            .customizationID(column.id)

                        case .organizationalResource:
                            TableColumn(appState.localized(column.label), value: \.organizationalResourceSortKey) { (resource: Resource) in
                                Text(resource.organizationalResource ?? "-")
                            }
                            .width(min: 140, ideal: 190)
                            .customizationID(column.id)

                        case .competence1:
                            TableColumn(appState.localized(column.label), value: \.competence1SortKey) { (resource: Resource) in
                                Text(resource.competence1 ?? "-")
                            }
                            .width(min: 120, ideal: 160)
                            .customizationID(column.id)

                        case .resourceCalendar:
                            TableColumn(appState.localized(column.label), value: \.resourceCalendarSortKey) { (resource: Resource) in
                                Text(resource.resourceCalendar ?? "-")
                            }
                            .width(min: 120, ideal: 160)
                            .customizationID(column.id)

                        case .resourceStartDate:
                            TableColumn(appState.localized(column.label), value: \.resourceStartDateSortKey) { (resource: Resource) in
                                Text(resource.resourceStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            }
                            .width(min: 110, ideal: 140)
                            .customizationID(column.id)

                        case .resourceFinishDate:
                            TableColumn(appState.localized(column.label), value: \.resourceFinishDateSortKey) { (resource: Resource) in
                                Text(resource.resourceFinishDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            }
                            .width(min: 110, ideal: 140)
                            .customizationID(column.id)

                        case .responsableOperationnel:
                            TableColumn(appState.localized(column.label), value: \.responsableOperationnelSortKey) { (resource: Resource) in
                                Text(resource.responsableOperationnel ?? "-")
                            }
                            .width(min: 120, ideal: 170)
                            .customizationID(column.id)

                        case .responsableInterne:
                            TableColumn(appState.localized(column.label), value: \.responsableInterneSortKey) { (resource: Resource) in
                                Text(resource.responsableInterne ?? "-")
                            }
                            .width(min: 130, ideal: 170)
                            .customizationID(column.id)

                        case .localisation:
                            TableColumn(appState.localized(column.label), value: \.localisationSortKey) { (resource: Resource) in
                                Text(resource.localisation ?? "-")
                            }
                            .width(min: 110, ideal: 150)
                            .customizationID(column.id)

                        case .typeDeRessource:
                            TableColumn(appState.localized(column.label), value: \.typeDeRessourceSortKey) { (resource: Resource) in
                                Text(resource.typeDeRessource ?? "-")
                            }
                            .width(min: 100, ideal: 140)
                            .customizationID(column.id)

                        case .journeesTempsPartiel:
                            TableColumn(appState.localized(column.label), value: \.journeesTempsPartielSortKey) { (resource: Resource) in
                                Text(resource.journeesTempsPartiel ?? "-")
                            }
                            .width(min: 100, ideal: 140)
                            .customizationID(column.id)

                        case .notes:
                            TableColumn(appState.localized(column.label), value: \.notes) { (resource: Resource) in
                                Text(resource.notes.isEmpty ? "-" : resource.notes)
                            }
                            .width(min: 160, ideal: 260)
                            .customizationID(column.id)

                        case .createdAt:
                            TableColumn(appState.localized(column.label), value: \.createdAt) { (resource: Resource) in
                                Text(resource.createdAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .width(min: 110, ideal: 140)
                            .customizationID(column.id)

                        case .updatedAt:
                            TableColumn(appState.localized(column.label), value: \.updatedAt) { (resource: Resource) in
                                Text(resource.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .width(min: 110, ideal: 140)
                            .customizationID(column.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scrollIndicators(.visible)
                .contextMenu(forSelectionType: Resource.ID.self) { _ in
                } primaryAction: { ids in
                    if let id = ids.first {
                        presentation.show(.edit(id))
                    }
                }
            }
        }
    }

    private func projectNames(for projectIDs: [UUID]) -> [String] {
        projectIDs.compactMap { store.project(with: $0)?.name }
    }

    private func scopedEvaluations(for resource: Resource) -> [ResourcePerformanceEvaluation] {
        let evaluations = resource.performanceEvaluations.sorted { $0.evaluatedAt < $1.evaluatedAt }
        guard let scopedProjectID else { return evaluations }
        return evaluations.filter { $0.projectID == nil || $0.projectID == scopedProjectID }
    }

    private func inlineTextBinding(for resource: Resource, field: WritableKeyPath<ResourceInlineDraft, String>) -> Binding<String> {
        Binding(
            get: { draftForInlineEdition(resource)[keyPath: field] },
            set: { newValue in
                var draft = draftForInlineEdition(resource)
                draft[keyPath: field] = newValue
                inlineDrafts[resource.id] = draft
            }
        )
    }

    private func inlineStatusBinding(for resource: Resource) -> Binding<ResourceStatus> {
        Binding(
            get: { draftForInlineEdition(resource).status },
            set: { newValue in
                var draft = draftForInlineEdition(resource)
                draft.status = newValue
                inlineDrafts[resource.id] = draft
                _ = saveInlineEdition(resourceID: resource.id)
            }
        )
    }

    private func inlineEngagementBinding(for resource: Resource) -> Binding<ResourceEngagement> {
        Binding(
            get: { draftForInlineEdition(resource).engagement },
            set: { newValue in
                var draft = draftForInlineEdition(resource)
                draft.engagement = newValue
                inlineDrafts[resource.id] = draft
                _ = saveInlineEdition(resourceID: resource.id)
            }
        )
    }

    private func draftForInlineEdition(_ resource: Resource) -> ResourceInlineDraft {
        if let cached = inlineDrafts[resource.id] {
            return cached
        }

        let freshDraft = ResourceInlineDraft(resource: resource)
        inlineDrafts[resource.id] = freshDraft
        return freshDraft
    }

    private func handleInlineSubmit(resourceID: UUID, column: ResourceInlineColumn) {
        guard saveInlineEdition(resourceID: resourceID) else { return }
        focusedInlineCell = nextInlineCell(after: .init(resourceID: resourceID, column: column))
    }

    private func saveInlineEdition(resourceID: UUID) -> Bool {
        guard let resource = store.resource(with: resourceID) else { return false }
        let draft = inlineDrafts[resourceID] ?? ResourceInlineDraft(resource: resource)

        let trimmedNom = draft.nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNom.isEmpty == false else {
            showFeedback("Mise à jour rapide", "Le nom ne peut pas être vide.")
            return false
        }

        let allocationRaw = draft.allocationPercentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let allocation = Int(allocationRaw), (0...100).contains(allocation) else {
            showFeedback("Mise à jour rapide", "Allocation invalide. Saisis une valeur entière entre 0 et 100.")
            return false
        }

        store.updateResourceQuick(
            resourceID: resourceID,
            nom: trimmedNom,
            parentDescription: draft.parentDescription,
            primaryResourceRole: draft.primaryResourceRole,
            email: draft.email,
            phone: draft.phone,
            allocationPercent: allocation,
            status: draft.status,
            engagement: draft.engagement
        )

        if let refreshed = store.resource(with: resourceID) {
            inlineDrafts[resourceID] = ResourceInlineDraft(resource: refreshed)
        }

        return true
    }

    private func nextInlineCell(after key: ResourceInlineCellKey) -> ResourceInlineCellKey? {
        guard let rowIndex = filteredResources.firstIndex(where: { $0.id == key.resourceID }),
              let columnIndex = visibleInlineNavigationOrder.firstIndex(of: key.column) else {
            return nil
        }

        let nextColumnIndex = columnIndex + 1
        if visibleInlineNavigationOrder.indices.contains(nextColumnIndex) {
            return ResourceInlineCellKey(
                resourceID: key.resourceID,
                column: visibleInlineNavigationOrder[nextColumnIndex]
            )
        }

        let nextRowIndex = rowIndex + 1
        guard filteredResources.indices.contains(nextRowIndex) else { return nil }
        return ResourceInlineCellKey(
            resourceID: filteredResources[nextRowIndex].id,
            column: visibleInlineNavigationOrder.first ?? .name
        )
    }

    private var visibleInlineNavigationOrder: [ResourceInlineColumn] {
        ResourceInlineColumn.navigationOrder.filter { column in
            switch column {
            case .name:
                return isColumnVisible(.name)
            case .role:
                return isColumnVisible(.primaryResourceRole)
            case .department:
                return isColumnVisible(.parentDescription)
            case .allocation:
                return isColumnVisible(.allocationPercent)
            case .email:
                return isColumnVisible(.email)
            case .phone:
                return isColumnVisible(.phone)
            }
        }
    }

    private func toggleResourceSelectionForExport(_ resourceID: UUID) {
        if selectedResourceIDs.contains(resourceID) {
            selectedResourceIDs.remove(resourceID)
        } else {
            selectedResourceIDs.insert(resourceID)
        }
    }

    private func canAssignResource(_ resource: Resource) -> Bool {
        guard let scopedProjectID else { return false }
        return resource.assignedProjectIDs.contains(scopedProjectID) == false
    }

    private func canToggleFavorite(_ resource: Resource) -> Bool {
        guard let scopedProjectID else { return false }
        return resource.assignedProjectIDs.contains(scopedProjectID)
    }

    private func canRemoveResource(_ resource: Resource) -> Bool {
        guard let scopedProjectID else { return false }
        return resource.assignedProjectIDs.contains(scopedProjectID)
    }

    private func assignSelectedResourceToScopedProject() {
        guard let selectedResource else { return }
        assignResourceToScopedProject(selectedResource.id)
    }

    private func assignResourceToScopedProject(_ resourceID: UUID) {
        guard let scopedProjectID else { return }
        store.assignResource(resourceID: resourceID, to: scopedProjectID)
    }

    private func removeResourceFromScopedProject(_ resourceID: UUID) {
        guard let scopedProjectID else { return }
        store.unassignResource(resourceID: resourceID, from: scopedProjectID)
    }

    private func projectRemovalConfirmationMessage(for resource: Resource) -> String {
        let projectID = scopedProjectID
        let activities = store.actions.filter {
            $0.assignedResourceID == resource.id && (projectID == nil || $0.projectID == projectID)
        }.count
        let events = store.events.filter {
            $0.resourceIDs.contains(resource.id) && (projectID == nil || $0.projectID == projectID)
        }.count
        let decisions = store.decisions.filter {
            $0.impactedResourceIDs.contains(resource.id) && (projectID == nil || $0.projectID == projectID)
        }.count

        var links: [String] = []
        if activities > 0 { links.append("\(activities) " + localized(activities > 1 ? "activités" : "activité")) }
        if events > 0 { links.append("\(events) " + localized(events > 1 ? "événements" : "événement")) }
        if decisions > 0 { links.append("\(decisions) " + localized(decisions > 1 ? "décisions" : "décision")) }

        let name = resource.displayName
        if links.isEmpty {
            return AppLocalizer.localizedFormat(
                "Voulez-vous vraiment retirer %@ du projet ?",
                language: appState.interfaceLanguage, name
            )
        }
        return AppLocalizer.localizedFormat(
            "Voulez-vous vraiment retirer %@ du projet ? %@ est lié à %@.",
            language: appState.interfaceLanguage, name, name, links.joined(separator: ", ")
        )
    }

    private func toggleFavoriteForScopedProject(_ resourceID: UUID) {
        guard let scopedProjectID else { return }
        store.toggleFavoriteResource(resourceID: resourceID, in: scopedProjectID)
    }

    private func prepareExport(resources: [Resource], defaultFilename: String) {
        do {
            let projectNamesByID = Dictionary(uniqueKeysWithValues: store.projects.map { ($0.id, $0.name) })
            let sortedResources = resources.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            let exportedData = try ResourceExportService.makeXLSXData(
                resources: sortedResources,
                projectNamesByID: projectNamesByID
            )
            exportDocument = ResourceExportDocument(data: exportedData)
            exportFilename = defaultFilename
            presentation.show(.exportFile)
        } catch {
            showFeedback("Export des ressources", error.localizedDescription)
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else {
            if case .failure(let error) = result {
                if !Task.isCancelled { showFeedback("Import des ressources", error.localizedDescription) }
            }
            return
        }

        let tracker = ImportProgressTracker(
            title: "Lecture du fichier",
            fileName: fileURL.lastPathComponent
        )
        appState.showImportProgress(tracker)
        isImporting = true

        let task = Task { @MainActor in
            let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScope {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                if appState.activeImportTracker?.id == tracker.id { isImporting = false }
                appState.clearImportProgress(tracker)
            }

            let reporter = ImportProgressReporter.forwarding(to: tracker)
            let importURL = fileURL

            do {
                let drafts = try await Task.detached(priority: .userInitiated) { () throws -> [ResourceImportDraft] in
                    try ResourceImportService.importResources(from: importURL, reporter: reporter)
                }.value

                try Task.checkCancellation()

                if drafts.isEmpty {
                    showFeedback("Import des ressources", "Aucune ligne exploitable à importer.")
                    return
                }

                presentation.show(.confirmImport(drafts))
            } catch is CancellationError {
                // annulation silencieuse
            } catch {
                if !Task.isCancelled { showFeedback("Import des ressources", error.localizedDescription) }
            }
        }
        tracker.task = task
        activeImportTask = task
    }

    private func cancelActiveImport() {
        activeImportTask?.cancel()
        activeImportTask = nil
        presentation.dismissAll()
        isImporting = false
    }

    private func proceedWithPendingImport(_ drafts: [ResourceImportDraft]) {
        presentation.dismissAll()

        let tracker = ImportProgressTracker(title: "Import des ressources")
        appState.showImportProgress(tracker)
        isImporting = true

        let currentStore = store
        let task = Task { @MainActor in
            defer {
                if appState.activeImportTracker?.id == tracker.id { isImporting = false }
                appState.clearImportProgress(tracker)
            }

            let reporter = ImportProgressReporter.forwarding(to: tracker)

            do {
                try Task.checkCancellation()

                let reviewItems = try await currentStore.prepareResourceImportReviewAsync(
                    drafts,
                    reporter: reporter
                )

                try Task.checkCancellation()
                if reviewItems.isEmpty {
                    showFeedback("Import des ressources", "Aucune ligne exploitable à importer.")
                    return
                }

                importReviewItems = reviewItems.map {
                    ResourceImportReviewDecision(
                        reviewItem: $0,
                        shouldApply: $0.action == .create
                    )
                }
                presentation.show(.review)
            } catch is CancellationError {
                // annulation silencieuse
            } catch {
                if !Task.isCancelled { showFeedback("Import des ressources", error.localizedDescription) }
            }
        }
        tracker.task = task
        activeImportTask = task
    }

    private func applyImportReview() {
        let decisions = importReviewItems
        importReviewItems = []
        let tracker = ImportProgressTracker(title: "Intégration des ressources")
        appState.showImportProgress(tracker)
        isImporting = true
        presentation.dismissAll()

        let currentStore = store
        let task = Task { @MainActor in
            defer {
                if appState.activeImportTracker?.id == tracker.id { isImporting = false }
                appState.clearImportProgress(tracker)
            }

            let reporter = ImportProgressReporter.forwarding(to: tracker)
            do {
                let result = try await currentStore.applyResourceImportReviewAsync(
                    decisions.map(\.reviewItem),
                    decisions: decisions.map {
                        ResourceImportDecision(reviewItemID: $0.reviewItem.id, shouldApply: $0.shouldApply)
                    },
                    reporter: reporter
                )

                try Task.checkCancellation()
                if let resourceID = result.firstImportedOrUpdatedResourceID {
                    appState.selectedResourceID = resourceID
                    appState.selectedSection = .resources
                }

                showFeedback("Import des ressources", "Import terminé : \(result.summary)")
                importReviewItems = []
            } catch is CancellationError {
                // Cancellation closes the progress UI without reopening an alert after navigation.
            } catch {
                if !Task.isCancelled { showFeedback("Import des ressources", error.localizedDescription) }
            }
        }
        tracker.task = task
        activeImportTask = task
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private enum SamouraiImportContentTypes {
    static let allowedTypes: [UTType] = [
        UTType(filenameExtension: "xlsx") ?? .data,
        .commaSeparatedText,
        .tabSeparatedText
    ]
}

private enum SamouraiExportContentTypes {
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .data
}

private struct ResourceExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [SamouraiExportContentTypes.xlsx] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct ResourceInlineDraft {
    var nom: String
    var primaryResourceRole: String
    var parentDescription: String
    var email: String
    var phone: String
    var allocationPercentText: String
    var status: ResourceStatus
    var engagement: ResourceEngagement

    init(resource: Resource) {
        nom = resource.displayName
        primaryResourceRole = resource.primaryResourceRole ?? resource.displayPrimaryRole
        parentDescription = resource.parentDescription ?? resource.displayDepartment
        email = resource.email
        phone = resource.phone
        allocationPercentText = "\(resource.allocationPercent)"
        status = resource.status
        engagement = resource.engagement
    }
}

private enum ResourceInlineColumn: CaseIterable, Hashable {
    case name
    case role
    case department
    case allocation
    case email
    case phone

    static let navigationOrder: [ResourceInlineColumn] = [.name, .role, .department, .allocation, .email, .phone]
}

private struct ResourceInlineCellKey: Hashable {
    let resourceID: UUID
    let column: ResourceInlineColumn
}

private enum ResourceTableColumn: String, CaseIterable, Identifiable, Hashable {
    case name
    case primaryResourceRole
    case parentDescription
    case projects
    case allocationPercent
    case status
    case engagement
    case email
    case phone
    case resourceRoles
    case organizationalResource
    case competence1
    case resourceCalendar
    case resourceStartDate
    case resourceFinishDate
    case responsableOperationnel
    case responsableInterne
    case localisation
    case typeDeRessource
    case journeesTempsPartiel
    case notes
    case createdAt
    case updatedAt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name:
            "Nom"
        case .primaryResourceRole:
            "Primary Role"
        case .parentDescription:
            "Parent Description"
        case .projects:
            "Projet(s)"
        case .allocationPercent:
            "Allocation"
        case .status:
            "Statut"
        case .engagement:
            "Engagement"
        case .email:
            "E-mail"
        case .phone:
            "Téléphone"
        case .resourceRoles:
            "Resource Roles"
        case .organizationalResource:
            "Organizational Resource"
        case .competence1:
            "Compétence 1"
        case .resourceCalendar:
            "Resource Calendar"
        case .resourceStartDate:
            "Resource Start Date"
        case .resourceFinishDate:
            "Resource Finish Date"
        case .responsableOperationnel:
            "Responsable Opérationnel"
        case .responsableInterne:
            "Responsable Interne"
        case .localisation:
            "Localisation"
        case .typeDeRessource:
            "Type de Ressource"
        case .journeesTempsPartiel:
            "Journée(s) temps partiel"
        case .notes:
            "Notes"
        case .createdAt:
            "Créée le"
        case .updatedAt:
            "Modifiée le"
        }
    }

}

private enum ResourceProjectFavoriteFilter: String, CaseIterable, Identifiable {
    case all
    case favoritesOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            "Toutes"
        case .favoritesOnly:
            "Favoris"
        }
    }
}

private enum ResourceDisplayMode: String, CaseIterable, Identifiable {
    case grid
    case table

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grid:
            "Grille"
        case .table:
            "Tableau"
        }
    }

    var iconName: String {
        switch self {
        case .grid:
            "square.grid.2x2"
        case .table:
            "tablecells"
        }
    }
}

private extension Resource {
    var assignedProjectCount: Int { assignedProjectIDs.count }
    var primaryResourceRoleSortKey: String { primaryResourceRole ?? "" }
    var parentDescriptionSortKey: String { parentDescription ?? "" }
    var statusSortKey: String { status.rawValue }
    var engagementSortKey: String { engagement.rawValue }
    var resourceRolesSortKey: String { resourceRoles ?? "" }
    var organizationalResourceSortKey: String { organizationalResource ?? "" }
    var competence1SortKey: String { competence1 ?? "" }
    var resourceCalendarSortKey: String { resourceCalendar ?? "" }
    var resourceStartDateSortKey: Date { resourceStartDate ?? .distantPast }
    var resourceFinishDateSortKey: Date { resourceFinishDate ?? .distantPast }
    var responsableOperationnelSortKey: String { responsableOperationnel ?? "" }
    var responsableInterneSortKey: String { responsableInterne ?? "" }
    var localisationSortKey: String { localisation ?? "" }
    var typeDeRessourceSortKey: String { typeDeRessource ?? "" }
    var journeesTempsPartielSortKey: String { journeesTempsPartiel ?? "" }
}
