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

    @State private var editorContext: ResourceEditorContext?
    @State private var resourcePendingDeletion: Resource?
    @State private var resourcesPendingBulkDeletion: [Resource] = []
    @State private var resourcePendingProjectRemoval: Resource?
    @State private var isShowingFileImporter = false
    @State private var isShowingDirectoryPicker = false
    @State private var importFeedbackMessage: String?
    @State private var isImporting = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: ResourceExportDocument?
    @State private var exportFilename = "ressources"
    @State private var exportFeedbackMessage: String?
    @State private var searchText = ""
    @State private var searchCache = ResourceSearchCache()
    @State private var selectedResourceIDs: Set<UUID> = []
    @State private var importReviewItems: [ResourceImportReviewDecision] = []
    @State private var isShowingImportReview = false
    @State private var pendingImportDrafts: [ResourceImportDraft]?
    @State private var isShowingImportConfirmation = false
    @State private var activeImportTask: Task<Void, Never>?
    @State private var inlineDrafts: [UUID: ResourceInlineDraft] = [:]
    @State private var inlineEditFeedbackMessage: String?
    @State private var evaluationContext: ResourceEvaluationContext?
    @State private var evaluationFeedbackMessage: String?
    @State private var memoPreviewResourceID: UUID?
    @State private var templateManagementResourceID: UUID?
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
                                resourcePendingProjectRemoval = selectedResource
                            } label: {
                                Label(localized("Retirer du projet"), systemImage: "minus.circle")
                            }
                            .disabled(isImporting)
                        }

                        if scopeMode == .contextualProject {
                            Button {
                                memoPreviewResourceID = selectedResource.id
                            } label: {
                                Label(localized("Mémo"), systemImage: "doc.text.magnifyingglass")
                            }
                            .disabled(isImporting)

                            Button {
                                evaluationContext = .init(resourceID: selectedResource.id)
                            } label: {
                                Label(localized("Évaluer"), systemImage: "waveform.path.ecg.rectangle")
                            }
                            .disabled(isImporting)
                        }

                        if scopeMode == .globalDirectory {
                            Button {
                                templateManagementResourceID = selectedResource.id
                            } label: {
                                Label(localized("Ressources liées"), systemImage: "doc.on.doc")
                            }
                            .disabled(isImporting)
                        }
                    }

                    if !resourceDeletionTargets.isEmpty {
                        Button {
                            if let id = resourceEditTargetID { editorContext = .edit(id) }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(isImporting || resourceEditTargetID == nil)

                        Button(role: .destructive) {
                            let targets = resourceDeletionTargets
                            if targets.count <= 1 {
                                resourcePendingDeletion = targets.first
                            } else {
                                resourcesPendingBulkDeletion = targets
                            }
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
                            isShowingFileImporter = true
                        } label: {
                            Label(localized("Importer"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(isImporting)

                        Button {
                            editorContext = .create
                        } label: {
                            Label(localized("Nouvelle"), systemImage: "plus")
                        }
                        .disabled(isImporting)
                    } else if scopedProjectID != nil {
                        Button {
                            isShowingDirectoryPicker = true
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
                                evaluationContext = .init(resourceID: resourceID)
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
        .sheet(isPresented: Binding(
            get: { editorContext != nil || evaluationContext != nil },
            set: { isPresented in
                if isPresented == false {
                    editorContext = nil
                    evaluationContext = nil
                }
            }
        )) {
            if let context = editorContext {
                ResourceEditorSheet(resource: context.resource(in: store))
            } else if let context = evaluationContext {
                if let resource = store.resource(with: context.resourceID) {
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
                            evaluationFeedbackMessage = "Évaluation enregistrée pour \(resource.displayName)."
                        }
                    )
                } else {
                    Text(localized("Ressource introuvable."))
                        .padding(24)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: SamouraiImportContentTypes.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: $isShowingDirectoryPicker) {
            if let projectID = scopedProjectID {
                ResourceDirectoryPickerSheet(
                    projectID: projectID,
                    projectName: scopedProjectName ?? ""
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { templateManagementResourceID != nil },
            set: { if $0 == false { templateManagementResourceID = nil } }
        )) {
            if let tid = templateManagementResourceID, let template = store.resource(with: tid) {
                ResourceTemplateManagementSheet(
                    template: template,
                    onLink: { resourceID in store.assignTemplate(resourceID: resourceID, templateID: tid) },
                    onUnlink: { resourceID in store.unassignTemplate(resourceID: resourceID) }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { memoPreviewResourceID != nil },
            set: { if $0 == false { memoPreviewResourceID = nil } }
        )) {
            if let resourceID = memoPreviewResourceID, let resource = store.resource(with: resourceID) {
                ResourceMemoPreviewSheet(resource: resource)
            } else {
                Text(localized("Ressource introuvable."))
                    .padding(24)
            }
        }
        .sheet(isPresented: $isShowingImportReview) {
            ResourceImportReviewSheet(
                decisions: $importReviewItems,
                onCancel: {
                    importReviewItems = []
                    isShowingImportReview = false
                },
                onApply: {
                    applyImportReview()
                }
            )
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: SamouraiExportContentTypes.xlsx,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                exportFeedbackMessage = "Export terminé avec succès."
            case .failure(let error):
                exportFeedbackMessage = error.localizedDescription
            }
        }
        .alert(localized("Supprimer la ressource"), isPresented: Binding(
            get: { resourcePendingDeletion != nil },
            set: { if $0 == false { resourcePendingDeletion = nil } }
        )) {
            Button(localized("Supprimer"), role: .destructive) {
                if let resource = resourcePendingDeletion {
                    if appState.selectedResourceID == resource.id {
                        appState.selectedResourceID = nil
                    }
                    selectedResourceIDs.remove(resource.id)
                    store.deleteResource(resourceID: resource.id)
                }
                resourcePendingDeletion = nil
            }
            Button(localized("Annuler"), role: .cancel) {
                resourcePendingDeletion = nil
            }
        } message: {
            Text(localized("Cette action retirera la ressource du référentiel local."))
        }
        .alert(localized("Supprimer les ressources"), isPresented: Binding(
            get: { resourcesPendingBulkDeletion.isEmpty == false },
            set: { if $0 == false { resourcesPendingBulkDeletion = [] } }
        )) {
            Button(localized("Supprimer"), role: .destructive) {
                deleteResources(resourcesPendingBulkDeletion)
                resourcesPendingBulkDeletion = []
            }
            Button(localized("Annuler"), role: .cancel) {
                resourcesPendingBulkDeletion = []
            }
        } message: {
            Text(appState.localizedFormat(
                "Voulez-vous vraiment supprimer %d ressources du référentiel local ?",
                resourcesPendingBulkDeletion.count
            ))
        }
        .alert(localized("Retirer la ressource du projet"), isPresented: Binding(
            get: { resourcePendingProjectRemoval != nil },
            set: { if $0 == false { resourcePendingProjectRemoval = nil } }
        )) {
            Button(localized("Oui"), role: .destructive) {
                if let resource = resourcePendingProjectRemoval {
                    removeResourceFromScopedProject(resource.id)
                }
                resourcePendingProjectRemoval = nil
            }
            Button(localized("Non"), role: .cancel) {
                resourcePendingProjectRemoval = nil
            }
        } message: {
            if let resource = resourcePendingProjectRemoval {
                Text(projectRemovalConfirmationMessage(for: resource))
            }
        }
        .alert(localized("Import des ressources"), isPresented: Binding(
            get: { importFeedbackMessage != nil },
            set: { if $0 == false { importFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(importFeedbackMessage ?? "")
        }
        .alert(localized("Confirmer l'import"), isPresented: $isShowingImportConfirmation) {
            Button(localized("Importer")) {
                proceedWithPendingImport()
            }
            Button(localized("Annuler"), role: .cancel) {
                cancelActiveImport()
            }
        } message: {
            let count = pendingImportDrafts?.count ?? 0
            Text(String(format: AppLocalizer.localized("%d ligne(s) détectée(s). Le traitement s'effectuera par lots de 10 lignes. Confirmer l'import ?"), count))
        }
        .alert(localized("Export des ressources"), isPresented: Binding(
            get: { exportFeedbackMessage != nil },
            set: { if $0 == false { exportFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(exportFeedbackMessage ?? "")
        }
        .alert(localized("Mise à jour rapide"), isPresented: Binding(
            get: { inlineEditFeedbackMessage != nil },
            set: { if $0 == false { inlineEditFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(inlineEditFeedbackMessage ?? "")
        }
        .alert(localized("Évaluation des ressources"), isPresented: Binding(
            get: { evaluationFeedbackMessage != nil },
            set: { if $0 == false { evaluationFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(evaluationFeedbackMessage ?? "")
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
                            onShowMemo: { memoPreviewResourceID = resource.id },
                            onEdit: { editorContext = .edit(resource.id) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResourceID.wrappedValue = resource.id
                        }
                        .contextMenu {
                            Button(localized("Modifier")) {
                                editorContext = .edit(resource.id)
                            }

                            Button(localized("Consulter le mémo")) {
                                memoPreviewResourceID = resource.id
                            }

                            Button(localized("Supprimer"), role: .destructive) {
                                resourcePendingDeletion = resource
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
                        editorContext = .edit(id)
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
            inlineEditFeedbackMessage = "Le nom ne peut pas être vide."
            return false
        }

        let allocationRaw = draft.allocationPercentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let allocation = Int(allocationRaw), (0...100).contains(allocation) else {
            inlineEditFeedbackMessage = "Allocation invalide. Saisis une valeur entière entre 0 et 100."
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
            isShowingFileExporter = true
        } catch {
            exportFeedbackMessage = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else {
            if case .failure(let error) = result {
                importFeedbackMessage = error.localizedDescription
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
                isImporting = false
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
                    importFeedbackMessage = "Aucune ligne exploitable à importer."
                    return
                }

                pendingImportDrafts = drafts
                isShowingImportConfirmation = true
            } catch is CancellationError {
                // annulation silencieuse
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
        tracker.task = task
        activeImportTask = task
    }

    private func cancelActiveImport() {
        activeImportTask?.cancel()
        activeImportTask = nil
        pendingImportDrafts = nil
        isImporting = false
    }

    private func proceedWithPendingImport() {
        guard let drafts = pendingImportDrafts else { return }
        pendingImportDrafts = nil

        let tracker = ImportProgressTracker(title: "Import des ressources")
        appState.showImportProgress(tracker)
        isImporting = true

        let currentStore = store
        let task = Task { @MainActor in
            defer {
                isImporting = false
                appState.clearImportProgress(tracker)
            }

            let reporter = ImportProgressReporter.forwarding(to: tracker)

            do {
                try Task.checkCancellation()

                let reviewItems = try await currentStore.prepareResourceImportReviewAsync(
                    drafts,
                    reporter: reporter
                )

                if reviewItems.isEmpty {
                    importFeedbackMessage = "Aucune ligne exploitable à importer."
                    return
                }

                importReviewItems = reviewItems.map {
                    ResourceImportReviewDecision(
                        reviewItem: $0,
                        shouldApply: $0.action == .create
                    )
                }
                isShowingImportReview = true
            } catch is CancellationError {
                // annulation silencieuse
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
        tracker.task = task
        activeImportTask = task
    }

    private func applyImportReview() {
        let decisions = importReviewItems
        let tracker = ImportProgressTracker(title: "Intégration des ressources")
        appState.showImportProgress(tracker)
        isImporting = true
        isShowingImportReview = false

        let currentStore = store
        tracker.task = Task { @MainActor in
            defer {
                isImporting = false
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

                if let resourceID = result.firstImportedOrUpdatedResourceID {
                    appState.selectedResourceID = resourceID
                    appState.selectedSection = .resources
                }

                importFeedbackMessage = "Import terminé : \(result.summary)"
                importReviewItems = []
            } catch is CancellationError {
                importFeedbackMessage = "Import annulé."
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
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

private struct ResourceEvaluationContext: Identifiable {
    let resourceID: UUID
    var id: UUID { resourceID }
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
