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
    @AppStorage("resources.visibleColumns") private var visibleColumnsRawValue = ResourceTableColumn.defaultVisibleRawValue

    @State private var editorContext: ResourceEditorContext?
    @State private var resourcePendingDeletion: Resource?
    @State private var isShowingFileImporter = false
    @State private var isShowingDirectoryPicker = false
    @State private var importFeedbackMessage: String?
    @State private var isImporting = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: ResourceExportDocument?
    @State private var exportFilename = "ressources"
    @State private var exportFeedbackMessage: String?
    @State private var searchText = ""
    @State private var selectedResourceIDs: Set<UUID> = []
    @State private var importReviewItems: [ResourceImportReviewDecision] = []
    @State private var isShowingImportReview = false
    @State private var isShowingColumnConfiguration = false
    @State private var inlineDrafts: [UUID: ResourceInlineDraft] = [:]
    @State private var inlineEditFeedbackMessage: String?
    @State private var evaluationContext: ResourceEvaluationContext?
    @State private var evaluationFeedbackMessage: String?
    @State private var projectFavoriteFilter: ResourceProjectFavoriteFilter = .all
    @State private var sortOrder: [KeyPathComparator<Resource>] = [
        .init(\.fullName, order: .reverse)
    ]
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
                        Text("\(filteredResources.count) / \(searchBaseResources.count) ressource(s) affichée(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let selectedResource = selectedResource {
                        if canAssignSelectedResourceToScopedProject {
                            Button {
                                assignSelectedResourceToScopedProject()
                            } label: {
                                Label("Ajouter au projet", systemImage: "plus.circle")
                            }
                            .disabled(isImporting)
                        } else if canRemoveSelectedResourceFromScopedProject {
                            Button {
                                removeSelectedResourceFromScopedProject()
                            } label: {
                                Label("Retirer du projet", systemImage: "minus.circle")
                            }
                            .disabled(isImporting)
                        }

                        if scopeMode == .contextualProject {
                            Button {
                                evaluationContext = .init(resourceID: selectedResource.id)
                            } label: {
                                Label("Évaluer", systemImage: "waveform.path.ecg.rectangle")
                            }
                            .disabled(isImporting)
                        }

                        Button {
                            editorContext = .edit(selectedResource.id)
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .disabled(isImporting)

                        Button(role: .destructive) {
                            resourcePendingDeletion = selectedResource
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        .disabled(isImporting)
                    }

                    Menu {
                        Button("Exporter toutes les ressources") {
                            prepareExport(
                                resources: scopedResources,
                                defaultFilename: "ressources-\(Date.now.formatted(.dateTime.year().month().day()))"
                            )
                        }

                        Button("Exporter la sélection (\(selectedResourcesForExport.count))") {
                            prepareExport(
                                resources: selectedResourcesForExport,
                                defaultFilename: "ressources-selection-\(Date.now.formatted(.dateTime.year().month().day()))"
                            )
                        }
                        .disabled(selectedResourcesForExport.isEmpty)
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isImporting || scopedResources.isEmpty)

                    if scopeMode == .globalDirectory {
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
                    } else if scopedProjectID != nil {
                        Button {
                            isShowingDirectoryPicker = true
                        } label: {
                            Label("Ajouter depuis l'annuaire", systemImage: "person.crop.circle.badge.plus")
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
                            Picker("Favoris", selection: $projectFavoriteFilter) {
                                ForEach(ResourceProjectFavoriteFilter.allCases) { filter in
                                    Text(filter.label).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }

                        Picker("Affichage", selection: displayModeBinding) {
                            ForEach(ResourceDisplayMode.allCases) { mode in
                                Label(mode.label, systemImage: mode.iconName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)

                        Button {
                            isShowingColumnConfiguration = true
                        } label: {
                            Label("Colonnes", systemImage: "slider.horizontal.3")
                        }
                        .help("Personnaliser les colonnes visibles")
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
                            description: Text("Ajuste la recherche pour retrouver une ressource de l'annuaire ou l'ajouter au projet en cours.")
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
                    Text("Ressource introuvable.")
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
        .sheet(isPresented: $isShowingColumnConfiguration) {
            ResourceColumnConfigurationSheet(
                visibleColumns: visibleColumnsBinding,
                onClose: { isShowingColumnConfiguration = false }
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
        .alert("Supprimer la ressource", isPresented: Binding(
            get: { resourcePendingDeletion != nil },
            set: { if $0 == false { resourcePendingDeletion = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let resource = resourcePendingDeletion {
                    if appState.selectedResourceID == resource.id {
                        appState.selectedResourceID = nil
                    }
                    selectedResourceIDs.remove(resource.id)
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
        .alert("Export des ressources", isPresented: Binding(
            get: { exportFeedbackMessage != nil },
            set: { if $0 == false { exportFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportFeedbackMessage ?? "")
        }
        .alert("Mise à jour rapide", isPresented: Binding(
            get: { inlineEditFeedbackMessage != nil },
            set: { if $0 == false { inlineEditFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inlineEditFeedbackMessage ?? "")
        }
        .alert("Évaluation des ressources", isPresented: Binding(
            get: { evaluationFeedbackMessage != nil },
            set: { if $0 == false { evaluationFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
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

    private var visibleColumnsBinding: Binding<Set<ResourceTableColumn>> {
        Binding(
            get: { visibleTableColumns },
            set: { newValue in
                visibleColumnsRawValue = ResourceTableColumn.encodeVisibleColumns(newValue)
            }
        )
    }

    private var visibleTableColumns: Set<ResourceTableColumn> {
        ResourceTableColumn.decodeVisibleColumns(visibleColumnsRawValue)
    }

    private func isColumnVisible(_ column: ResourceTableColumn) -> Bool {
        visibleTableColumns.contains(column)
    }

    private var activeTableColumns: [ResourceTableColumn] {
        let ordered = ResourceTableColumn.allCases.filter { visibleTableColumns.contains($0) }
        return Array(ordered.prefix(9))
    }

    private var searchBaseResources: [Resource] {
        if scopedProjectID != nil, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return store.resources
        }
        return scopedResources
    }

    private var filteredResources: [Resource] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return scopedResources
                .filter(matchesScopedFavoriteFilter)
                .sorted(using: sortOrder)
        }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return scopedResources.sorted(using: sortOrder) }

        return searchBaseResources.filter { resource in
            guard matchesScopedFavoriteFilter(resource) else { return false }
            let resourceProjectNames = projectNames(for: resource.assignedProjectIDs)
            let searchableValues = allSearchableValues(for: resource, assignedProjectNames: resourceProjectNames)
            let normalizedEmail = normalize(resource.email)

            return terms.allSatisfy { term in
                if term.hasPrefix("@") {
                    let domainToken = String(term.dropFirst())
                    guard domainToken.isEmpty == false else { return true }
                    return normalizedEmail.contains(domainToken)
                }

                return searchableValues.contains { normalize($0).contains(term) }
            }
        }
        .sorted(using: sortOrder)
    }

    private var scopedResources: [Resource] {
        if let primaryProjectID = scopedProjectID {
            return store.resources.filter { $0.assignedProjectIDs.contains(primaryProjectID) }
        }
        return store.resources
    }

    private func matchesScopedFavoriteFilter(_ resource: Resource) -> Bool {
        guard let scopedProjectID else { return true }
        switch projectFavoriteFilter {
        case .all:
            return true
        case .favoritesOnly:
            return resource.isFavorite(in: scopedProjectID)
        }
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
                            onToggleExportSelection: {
                                toggleResourceSelectionForExport(resource.id)
                            },
                            onToggleFavorite: canToggleFavorite(resource)
                                ? ({ toggleFavoriteForScopedProject(resource.id) })
                                : nil,
                            onEdit: { editorContext = .edit(resource.id) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResourceID.wrappedValue = resource.id
                        }
                        .contextMenu {
                            Button("Modifier") {
                                editorContext = .edit(resource.id)
                            }

                            Button("Supprimer", role: .destructive) {
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
                if visibleTableColumns.count > activeTableColumns.count {
                    Text("Affichage limité à 9 colonnes simultanées pour garder la table lisible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                Table(filteredResources, selection: selectedResourceID, sortOrder: $sortOrder) {
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
                            TableColumn(column.label, value: \.fullName) { (resource: Resource) in
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

                        case .primaryResourceRole:
                            TableColumn(column.label, value: \.primaryResourceRoleSortKey) { (resource: Resource) in
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

                        case .parentDescription:
                            TableColumn(column.label, value: \.parentDescriptionSortKey) { (resource: Resource) in
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

                        case .projects:
                            TableColumn(column.label, value: \.assignedProjectCount) { (resource: Resource) in
                                let assignedProjectNames = projectNames(for: resource.assignedProjectIDs)
                                Text(assignedProjectNames.isEmpty ? "-" : assignedProjectNames.joined(separator: ", "))
                            }
                            .width(min: 180, ideal: 260)

                        case .allocationPercent:
                            TableColumn(column.label, value: \.allocationPercent) { (resource: Resource) in
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

                        case .status:
                            TableColumn(column.label, value: \.statusSortKey) { (resource: Resource) in
                                Picker(
                                    "Statut",
                                    selection: inlineStatusBinding(for: resource)
                                ) {
                                    ForEach(ResourceStatus.allCases) { status in
                                        Text(status.label).tag(status)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .width(min: 100, ideal: 130)

                        case .engagement:
                            TableColumn(column.label, value: \.engagementSortKey) { (resource: Resource) in
                                Picker(
                                    "Engagement",
                                    selection: inlineEngagementBinding(for: resource)
                                ) {
                                    ForEach(ResourceEngagement.allCases) { engagement in
                                        Text(engagement.label).tag(engagement)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .width(min: 100, ideal: 140)

                        case .email:
                            TableColumn(column.label, value: \.email) { (resource: Resource) in
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

                        case .phone:
                            TableColumn(column.label, value: \.phone) { (resource: Resource) in
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

                        case .resourceRoles:
                            TableColumn(column.label, value: \.resourceRolesSortKey) { (resource: Resource) in
                                Text(resource.resourceRoles ?? "-")
                            }
                            .width(min: 140, ideal: 190)

                        case .organizationalResource:
                            TableColumn(column.label, value: \.organizationalResourceSortKey) { (resource: Resource) in
                                Text(resource.organizationalResource ?? "-")
                            }
                            .width(min: 140, ideal: 190)

                        case .competence1:
                            TableColumn(column.label, value: \.competence1SortKey) { (resource: Resource) in
                                Text(resource.competence1 ?? "-")
                            }
                            .width(min: 120, ideal: 160)

                        case .resourceCalendar:
                            TableColumn(column.label, value: \.resourceCalendarSortKey) { (resource: Resource) in
                                Text(resource.resourceCalendar ?? "-")
                            }
                            .width(min: 120, ideal: 160)

                        case .resourceStartDate:
                            TableColumn(column.label, value: \.resourceStartDateSortKey) { (resource: Resource) in
                                Text(resource.resourceStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            }
                            .width(min: 110, ideal: 140)

                        case .resourceFinishDate:
                            TableColumn(column.label, value: \.resourceFinishDateSortKey) { (resource: Resource) in
                                Text(resource.resourceFinishDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            }
                            .width(min: 110, ideal: 140)

                        case .responsableOperationnel:
                            TableColumn(column.label, value: \.responsableOperationnelSortKey) { (resource: Resource) in
                                Text(resource.responsableOperationnel ?? "-")
                            }
                            .width(min: 120, ideal: 170)

                        case .responsableInterne:
                            TableColumn(column.label, value: \.responsableInterneSortKey) { (resource: Resource) in
                                Text(resource.responsableInterne ?? "-")
                            }
                            .width(min: 130, ideal: 170)

                        case .localisation:
                            TableColumn(column.label, value: \.localisationSortKey) { (resource: Resource) in
                                Text(resource.localisation ?? "-")
                            }
                            .width(min: 110, ideal: 150)

                        case .typeDeRessource:
                            TableColumn(column.label, value: \.typeDeRessourceSortKey) { (resource: Resource) in
                                Text(resource.typeDeRessource ?? "-")
                            }
                            .width(min: 100, ideal: 140)

                        case .journeesTempsPartiel:
                            TableColumn(column.label, value: \.journeesTempsPartielSortKey) { (resource: Resource) in
                                Text(resource.journeesTempsPartiel ?? "-")
                            }
                            .width(min: 100, ideal: 140)

                        case .notes:
                            TableColumn(column.label, value: \.notes) { (resource: Resource) in
                                Text(resource.notes.isEmpty ? "-" : resource.notes)
                            }
                            .width(min: 160, ideal: 260)

                        case .createdAt:
                            TableColumn(column.label, value: \.createdAt) { (resource: Resource) in
                                Text(resource.createdAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .width(min: 110, ideal: 140)

                        case .updatedAt:
                            TableColumn(column.label, value: \.updatedAt) { (resource: Resource) in
                                Text(resource.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .width(min: 110, ideal: 140)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scrollIndicators(.visible)
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

    private func allSearchableValues(for resource: Resource, assignedProjectNames: [String]) -> [String] {
        [
            resource.displayName,
            resource.fullName,
            resource.nom ?? "",
            resource.displayPrimaryRole,
            resource.primaryResourceRole ?? "",
            resource.resourceRoles ?? "",
            resource.jobTitle,
            resource.displayDepartment,
            resource.parentDescription ?? "",
            resource.organizationalResource ?? "",
            assignedProjectNames.joined(separator: ", "),
            resource.engagement.label,
            resource.status.label,
            resource.allocationLabel,
            "\(resource.allocationPercent)",
            resource.email,
            resource.phone,
            resource.notes,
            resource.localisation ?? "",
            resource.typeDeRessource ?? "",
            resource.competence1 ?? "",
            resource.resourceCalendar ?? "",
            resource.responsableOperationnel ?? "",
            resource.responsableInterne ?? "",
            resource.createdAt.formatted(date: .abbreviated, time: .omitted),
            resource.updatedAt.formatted(date: .abbreviated, time: .omitted)
        ]
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func removeSelectedResourceFromScopedProject() {
        guard let selectedResource else { return }
        removeResourceFromScopedProject(selectedResource.id)
    }

    private func assignResourceToScopedProject(_ resourceID: UUID) {
        guard let scopedProjectID else { return }
        store.assignResource(resourceID: resourceID, to: scopedProjectID)
    }

    private func removeResourceFromScopedProject(_ resourceID: UUID) {
        guard let scopedProjectID else { return }
        store.unassignResource(resourceID: resourceID, from: scopedProjectID)
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
            title: "Import des ressources",
            fileName: fileURL.lastPathComponent
        )
        appState.showImportProgress(tracker)
        isImporting = true

        let currentStore = store
        tracker.task = Task { @MainActor in
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
                // Parse off the main actor so the UI stays responsive.
                let drafts = try await Task.detached(priority: .userInitiated) { () throws -> [ResourceImportDraft] in
                    try ResourceImportService.importResources(from: importURL, reporter: reporter)
                }.value

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
                importFeedbackMessage = "Import annulé."
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
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
}

private struct ResourceProfilingSummaryCard: View {
    let report: ResourceProfilingReport
    let scopeLabel: String

    @AppStorage("resources.profilingSummaryExpanded") private var isExpanded = false

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gestion contextuelle des ressources")
                        .font(.headline)
                    Text(scopeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Profil complet à \(report.completionPercent)%")
                    .font(.subheadline.weight(.semibold))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Réduire les profils standard" : "Afficher les profils standard")
            }

            ProgressView(value: report.completionRatio)
                .progressViewStyle(.linear)

            HStack(spacing: 16) {
                Label("\(report.coveredCount)/\(report.requiredRoles.count) rôles pourvus", systemImage: "checkmark.seal")
                Label("\(report.missingRoles.count) lacune(s)", systemImage: "exclamationmark.triangle")
                Label("\(report.activeContributorCount) ressource(s) active(s)", systemImage: "circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isExpanded {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(report.roleCoverage) { coverage in
                        ResourceRoleCoverageRow(coverage: coverage)
                    }
                    .scrollIndicators(.visible)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ResourceRoleCoverageRow: View {
    let coverage: ResourceRoleCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(coverage.isCovered ? "✅" : "⚠️")
                Text(coverage.role.label)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            if coverage.assignedResources.isEmpty {
                Text("À pourvoir - aucune ressource assignée")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let assignedNames = coverage.assignedResources.map(\.displayName).joined(separator: ", ")
                let activeNames = coverage.activeResources.map(\.displayName).joined(separator: ", ")
                Text(assignedNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(activeNames.isEmpty ? "🔵 Actif: aucune contribution active" : "🔵 Actif: \(activeNames)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

private struct ResourceComparativePerformanceCard: View {
    let snapshots: [ResourcePerformanceSnapshot]
    let onEvaluate: (UUID) -> Void

    @AppStorage("resources.comparativePerformanceExpanded") private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Synthèse comparative de performance")
                    .font(.headline)
                Spacer()
                let atRiskCount = snapshots.filter { $0.alerts.isEmpty == false }.count
                Text("\(atRiskCount) profil(s) à risque")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Réduire la synthèse" : "Afficher la synthèse comparative")
            }

            if isExpanded {
                Group {
                    if snapshots.isEmpty {
                        Text("Aucune ressource disponible.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(snapshots.prefix(6)), id: \.resourceID) { snapshot in
                            HStack(spacing: 10) {
                                Text(snapshot.alerts.isEmpty ? "✅" : "⚠️")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snapshot.resourceName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(performanceSubtitle(for: snapshot))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Évaluer") {
                                    onEvaluate(snapshot.resourceID)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func performanceSubtitle(for snapshot: ResourcePerformanceSnapshot) -> String {
        let scoreText = snapshot.latestScore.map { String(format: "%.2f/5", $0) } ?? "Pas de note"
        let alertsText = snapshot.alerts.isEmpty ? "Aucune alerte" : snapshot.alerts.map(\.kind.label).joined(separator: " • ")
        return "\(scoreText) • \(snapshot.trend.label) • \(alertsText)"
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

    static let defaultVisibleColumns: Set<ResourceTableColumn> = [
        .name,
        .primaryResourceRole,
        .parentDescription,
        .projects,
        .allocationPercent,
        .status,
        .engagement,
        .email,
        .phone
    ]

    static var defaultVisibleRawValue: String {
        encodeVisibleColumns(defaultVisibleColumns)
    }

    static func decodeVisibleColumns(_ rawValue: String) -> Set<ResourceTableColumn> {
        let tokens = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let columns = Set(tokens.compactMap(ResourceTableColumn.init(rawValue:)))
        return columns.isEmpty ? defaultVisibleColumns : columns
    }

    static func encodeVisibleColumns(_ columns: Set<ResourceTableColumn>) -> String {
        let normalized = columns.isEmpty ? defaultVisibleColumns : columns
        return normalized
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
            .joined(separator: ",")
    }
}

private struct ResourceColumnConfigurationSheet: View {
    @Binding var visibleColumns: Set<ResourceTableColumn>
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active ou désactive les colonnes à afficher dans la vue tableau.")
                    .foregroundStyle(.secondary)

                List {
                    ForEach(ResourceTableColumn.allCases) { column in
                        Toggle(
                            column.label,
                            isOn: Binding(
                                get: { visibleColumns.contains(column) },
                                set: { isEnabled in
                                    if isEnabled {
                                        visibleColumns.insert(column)
                                    } else {
                                        visibleColumns.remove(column)
                                        if visibleColumns.isEmpty {
                                            visibleColumns = ResourceTableColumn.defaultVisibleColumns
                                        }
                                    }
                                }
                            )
                        )
                        .toggleStyle(.switch)
                    }
                }
                .listStyle(.inset)
                .scrollIndicators(.visible)
            }
            .padding(16)
            .navigationTitle("Colonnes Ressources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Fermer") {
                        onClose()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button("Par défaut") {
                        visibleColumns = ResourceTableColumn.defaultVisibleColumns
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button("Tout afficher") {
                        visibleColumns = Set(ResourceTableColumn.allCases)
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 560)
    }
}

private struct ResourceImportReviewDecision: Identifiable {
    let reviewItem: ResourceImportReviewItem
    var shouldApply: Bool

    var id: UUID { reviewItem.id }
}

private struct ResourceImportReviewSheet: View {
    @Binding var decisions: [ResourceImportReviewDecision]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Validation ligne par ligne")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button("Tout conserver") {
                        for index in decisions.indices where decisions[index].reviewItem.action == .update {
                            decisions[index].shouldApply = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Tout écraser") {
                        for index in decisions.indices where decisions[index].reviewItem.action == .update {
                            decisions[index].shouldApply = true
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }

                List {
                    ForEach($decisions) { $decision in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Ligne \(decision.reviewItem.sourceRowNumber)")
                                    .font(.headline)
                                Text(decision.reviewItem.displayName)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(actionLabel(for: decision.reviewItem.action))
                                    .foregroundStyle(actionColor(for: decision.reviewItem.action))
                            }

                            switch decision.reviewItem.action {
                            case .create, .update:
                                Toggle(
                                    decision.reviewItem.action == .update
                                        ? "Écraser les informations existantes avec l'import"
                                        : "Importer cette nouvelle ressource",
                                    isOn: $decision.shouldApply
                                )
                                    .toggleStyle(.checkbox)
                            case .noChange:
                                Text("Aucune modification détectée.")
                                    .foregroundStyle(.secondary)
                            case .skipped:
                                Text("Ligne ignorée (données insuffisantes).")
                                    .foregroundStyle(.secondary)
                            }

                            if decision.reviewItem.changes.isEmpty == false {
                                ForEach(decision.reviewItem.changes) { change in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(change.fieldLabel)
                                            .font(.caption.weight(.semibold))
                                            .frame(width: 170, alignment: .leading)
                                        Text(change.oldValue.isEmpty ? "-" : change.oldValue)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(change.newValue.isEmpty ? "-" : change.newValue)
                                            .font(.caption.monospaced())
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
                .scrollIndicators(.visible)
            }
            .padding(16)
            .navigationTitle("Revue d'import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        onApply()
                    }
                    .disabled(decisions.contains(where: { ($0.reviewItem.action == .update || $0.reviewItem.action == .create) && $0.shouldApply }) == false)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var summaryText: String {
        let updates = decisions.filter { $0.reviewItem.action == .update }.count
        let creates = decisions.filter { $0.reviewItem.action == .create }.count
        let unchanged = decisions.filter { $0.reviewItem.action == .noChange }.count
        let skipped = decisions.filter { $0.reviewItem.action == .skipped }.count
        return "\(creates) création(s), \(updates) mise(s) à jour, \(unchanged) inchangée(s), \(skipped) ignorée(s)"
    }

    private func actionLabel(for action: ResourceImportReviewAction) -> String {
        switch action {
        case .create:
            "Création"
        case .update:
            "Écrasement"
        case .noChange:
            "Inchangé"
        case .skipped:
            "Ignoré"
        }
    }

    private func actionColor(for action: ResourceImportReviewAction) -> Color {
        switch action {
        case .create:
            .green
        case .update:
            .orange
        case .noChange:
            .secondary
        case .skipped:
            .secondary
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

private struct ResourceGridCard: View {
    let resource: Resource
    let assignedProjectNames: [String]
    let scopedProjectID: UUID?
    let isSelected: Bool
    let isMarkedForExport: Bool
    let onToggleExportSelection: () -> Void
    let onToggleFavorite: (() -> Void)?
    let onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(resource.displayName)
                    .font(.headline)
                    .onTapGesture(count: 2) { onEdit?() }
                Spacer()
                if let scopedProjectID, resource.assignedProjectIDs.contains(scopedProjectID) {
                    Button(action: {
                        onToggleFavorite?()
                    }) {
                        Image(systemName: resource.isFavorite(in: scopedProjectID) ? "star.fill" : "star")
                            .foregroundStyle(resource.isFavorite(in: scopedProjectID) ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onToggleExportSelection) {
                    Image(systemName: isMarkedForExport ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isMarkedForExport ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                Circle()
                    .fill(resource.status.tintColor)
                    .frame(width: 10, height: 10)
            }

            Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                .foregroundStyle(.secondary)

            HStack {
                Text(resource.allocationLabel)
                Spacer()
                Text(assignedProjectNames.isEmpty ? "Non affecté" : assignedProjectNames.joined(separator: ", "))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}

private struct ResourceEvaluationDraft {
    var evaluatedAt: Date = .now
    var milestone: String = "Fin de Sprint"
    var evaluator: String = "Chef de Projet"
    var comment: String = ""
    var scores: [ResourceEvaluationCriterion: ResourceEvaluationScale] = Dictionary(
        uniqueKeysWithValues: ResourceEvaluationCriterion.allCases.map { ($0, .satisfaisant) }
    )
}

private struct ResourceEvaluationPayload {
    let evaluatedAt: Date
    let milestone: String
    let evaluator: String
    let comment: String
    let criterionScores: [ResourceCriterionScore]
}

private struct ResourceEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let resource: Resource
    let scopedProject: Project?
    let onSave: (ResourceEvaluationPayload) -> Void

    @State private var draft = ResourceEvaluationDraft()
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Contexte") {
                    Text(resource.displayName)
                    DatePicker("Date", selection: $draft.evaluatedAt, displayedComponents: .date)
                    TextField("Jalon / Milestone", text: $draft.milestone)
                    TextField("Évaluateur", text: $draft.evaluator)
                    if let scopedProject {
                        Text("Projet: \(scopedProject.name) • Phase: \(scopedProject.phase.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Portée multi-projet (pondération standard)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notation structurée (1..5)") {
                    ForEach(ResourceEvaluationCriterion.allCases) { criterion in
                        Picker(criterion.label, selection: scoreBinding(for: criterion)) {
                            ForEach(ResourceEvaluationScale.allCases) { level in
                                Text("\(level.rawValue) - \(level.label)").tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Commentaire justificatif (obligatoire)") {
                    TextField("Observations détaillées", text: $draft.comment, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Nouvelle évaluation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        submit()
                    }
                    .disabled(draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 620)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button("Enregistrer") {
                    submit()
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
            captureInitialSnapshotIfNeeded()
        }
    }

    private var snapshot: String {
        [
            String(draft.evaluatedAt.timeIntervalSinceReferenceDate),
            draft.milestone,
            draft.evaluator,
            draft.comment,
            ResourceEvaluationCriterion.allCases.map { "\($0.rawValue):\(draft.scores[$0]?.rawValue ?? 0)" }.joined(separator: ",")
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

    private func submit() {
        onSave(payload())
        dismiss()
    }

    private func scoreBinding(for criterion: ResourceEvaluationCriterion) -> Binding<ResourceEvaluationScale> {
        Binding(
            get: { draft.scores[criterion] ?? .satisfaisant },
            set: { draft.scores[criterion] = $0 }
        )
    }

    private func payload() -> ResourceEvaluationPayload {
        let criterionScores = ResourceEvaluationCriterion.allCases.map { criterion in
            ResourceCriterionScore(
                criterion: criterion,
                score: draft.scores[criterion] ?? .satisfaisant
            )
        }
        return ResourceEvaluationPayload(
            evaluatedAt: draft.evaluatedAt,
            milestone: draft.milestone,
            evaluator: draft.evaluator,
            comment: draft.comment,
            criterionScores: criterionScores
        )
    }
}
