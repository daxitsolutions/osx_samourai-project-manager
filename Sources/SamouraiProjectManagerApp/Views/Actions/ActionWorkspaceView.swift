import SwiftUI

struct ActionWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var selectedFlow: ActionFlowFilter = .all
    @State private var editorContext: ActionEditorContext?
    @State private var actionPendingDeletion: ProjectAction?
    @State private var selectedActionIDs: Set<UUID> = []
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "actions"
    @State private var isShowingDeleteConfirmation = false
    @State private var sortOrder: [KeyPathComparator<ProjectAction>] = [
        .init(\.dueDate, order: .reverse)
    ]

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 760, sidebarIdealWidth: 900, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liste d'actions PM")
                            .font(.title2.weight(.semibold))
                        Text("\(filteredActions.count) / \(scopedActions.count) action(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedActionIDs.isEmpty == false {
                        Button {
                            if let selectedActionID = selectedActionIDs.singleSelection {
                                editorContext = .edit(selectedActionID)
                            }
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .disabled(selectedActionIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedActionIDs.count > 1 ? "Supprimer (\(selectedActionIDs.count))" : "Supprimer",
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button("Exporter la vue (\(filteredActions.count))") {
                            prepareExport(actions: filteredActions, filenameSuffix: "vue")
                        }
                        .disabled(filteredActions.isEmpty)

                        Button("Exporter la sélection (\(selectedActionsForExport.count))") {
                            prepareExport(actions: selectedActionsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedActionsForExport.isEmpty)
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create
                    } label: {
                        Label("Nouvelle action", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField("Recherche (titre, description, priorité, flux)", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("Flux", selection: $selectedFlow) {
                        ForEach(ActionFlowFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedActions.isEmpty {
                    ContentUnavailableView(
                        "Aucune action PM",
                        systemImage: "list.clipboard",
                        description: Text("Saisis les directives reçues pour les convertir en tâches opérationnelles du Chef de Projet.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredActions.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Ajuste la recherche ou le filtre de flux.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredActions, selection: $selectedActionIDs, sortOrder: $sortOrder) {
                        TableColumn("") { action in
                            Toggle(
                                "Terminée",
                                isOn: Binding(
                                    get: { action.isDone },
                                    set: { store.markActionDone(actionID: action.id, isDone: $0) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        }
                        .width(34)

                        TableColumn("Statut", value: \.statusSortKey) { action in
                            Picker(
                                "Statut",
                                selection: Binding(
                                    get: { action.status },
                                    set: { store.updateActionStatus(actionID: action.id, status: $0) }
                                )
                            ) {
                                ForEach(ActionStatus.allCases) { status in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(status.tintColor)
                                            .frame(width: 8, height: 8)
                                        Text(status.label)
                                    }
                                    .tag(status)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .width(min: 130, ideal: 145)

                        TableColumn("Flux", value: \.flowSortKey) { action in
                            Label(action.flow.label, systemImage: action.flow.systemImage)
                        }
                        .width(min: 160, ideal: 170)

                        TableColumn("Priorité", value: \.prioritySortWeight) { action in
                            Picker(
                                "Priorité",
                                selection: Binding(
                                    get: { action.priority },
                                    set: {
                                        store.updateAction(
                                            actionID: action.id,
                                            title: action.title,
                                            details: action.details,
                                            priority: $0,
                                            dueDate: action.dueDate,
                                            flow: action.flow,
                                            projectID: action.projectID
                                        )
                                    }
                                )
                            ) {
                                ForEach(ActionPriority.allCases) { priority in
                                    Text(priority.label).tag(priority)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .width(min: 110, ideal: 120)

                        TableColumn("Titre", value: \.displayTitle) { action in
                            TextField(
                                "Titre",
                                text: Binding(
                                    get: { action.title },
                                    set: {
                                        store.updateAction(
                                            actionID: action.id,
                                            title: $0,
                                            details: action.details,
                                            priority: action.priority,
                                            dueDate: action.dueDate,
                                            flow: action.flow,
                                            projectID: action.projectID
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                            .fontWeight(.medium)
                        }
                        .width(min: 220, ideal: 360)

                        TableColumn("Activité", value: \.activityIDSortKey) { action in
                            if let projectID = action.projectID {
                                Picker(
                                    "Activité",
                                    selection: Binding(
                                        get: { action.activityID },
                                        set: { store.assignActionToActivity(actionID: action.id, activityID: $0) }
                                    )
                                ) {
                                    Text("Aucune").tag(Optional<UUID>.none)
                                    ForEach(store.activities(for: projectID)) { activity in
                                        Text(activity.displayTitle).tag(Optional(activity.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            } else {
                                Text("-")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Projet", value: \.projectIDSortKey) { action in
                            Text(store.projectName(for: action.projectID))
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Échéance", value: \.dueDate) { action in
                            Text(action.dueDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .width(min: 120, ideal: 130)

                        TableColumn("Créée le", value: \.createdAt) { action in
                            Text(action.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 150, ideal: 170)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .frame(minWidth: 760, idealWidth: 900)

        } detail: {
            EmptyView()
        }
        .sheet(isPresented: Binding(
            get: { editorContext != nil },
            set: { if $0 == false { editorContext = nil } }
        )) {
            if let context = editorContext {
                ActionEditorSheet(action: context.action(in: store))
            }
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert("Supprimer l'action", isPresented: $isShowingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if selectedActionIDs.isEmpty == false {
                    for actionID in selectedActionIDs {
                        store.deleteAction(actionID: actionID)
                    }
                    selectedActionIDs.removeAll()
                    appState.selectedActionID = nil
                } else if let pending = actionPendingDeletion {
                    store.deleteAction(actionID: pending.id)
                }
                actionPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                selectedActionIDs.count > 1
                ? "Ces actions seront retirées de la liste proactive du PM."
                : "Cette action sera retirée de la liste proactive du PM."
            )
        }
        .onChange(of: selectedActionIDs) { _, newSelection in
            appState.selectedActionID = newSelection.singleSelection
        }
        .onChange(of: appState.selectedActionID) { _, newID in
            guard let newID else { return }
            if selectedActionIDs != [newID] {
                selectedActionIDs = [newID]
            }
        }
        .onChange(of: store.actions.map(\.id)) { _, actionIDs in
            let existingIDs = Set(actionIDs)
            selectedActionIDs = selectedActionIDs.intersection(existingIDs)
            appState.selectedActionID = selectedActionIDs.singleSelection
        }
    }

    private var filteredActions: [ProjectAction] {
        let flowFilteredActions: [ProjectAction]
        switch selectedFlow {
        case .all:
            flowFilteredActions = scopedActions
        case .manuel:
            flowFilteredActions = scopedActions.filter { $0.flow == .manuel }
        case .automatique:
            flowFilteredActions = scopedActions.filter { $0.flow == .automatique }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return flowFilteredActions.sorted(using: sortOrder) }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return flowFilteredActions.sorted(using: sortOrder) }

        return flowFilteredActions.filter { action in
            let searchableValues: [String] = [
                action.title,
                action.details,
                action.priority.label,
                action.flow.label,
                action.status.label,
                activityTitle(for: action.activityID),
                store.projectName(for: action.projectID),
                action.dueDate.formatted(date: .abbreviated, time: .omitted),
                action.createdAt.formatted(date: .abbreviated, time: .shortened),
                action.isDone ? "terminée" : "ouverte"
            ]
            let normalizedValues = searchableValues.map(normalize)
            return terms.allSatisfy { term in
                normalizedValues.contains(where: { $0.contains(term) })
            }
        }
        .sorted(using: sortOrder)
    }

    private var scopedActions: [ProjectAction] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.actions.filter { $0.projectID == primaryProjectID }
        }
        return store.actions
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedAction: ProjectAction? {
        guard let selectedActionID = selectedActionIDs.singleSelection else { return nil }
        return store.action(with: selectedActionID)
    }

    private func activityTitle(for activityID: UUID?) -> String {
        guard let activityID, let activity = store.activity(with: activityID) else { return "" }
        return activity.displayTitle
    }

    private var selectedActionsForExport: [ProjectAction] {
        filteredActions.filter { selectedActionIDs.contains($0.id) }
    }

    private func prepareExport(actions: [ProjectAction], filenameSuffix: String) {
        guard actions.isEmpty == false else { return }
        let headers = ["Titre", "Statut", "Priorite", "Flux", "Projet", "Activite", "Echeance", "Creee le"]
        let rows = actions.map { action in
            [
                action.displayTitle,
                action.status.label,
                action.priority.label,
                action.flow.label,
                store.projectName(for: action.projectID),
                activityTitle(for: action.activityID),
                action.dueDate.formatted(date: .abbreviated, time: .omitted),
                action.createdAt.formatted(date: .abbreviated, time: .shortened)
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-actions-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }
}

private extension ProjectAction {
    var flowSortKey: String { flow.rawValue }
    var prioritySortWeight: Int { priority.sortWeight }
    var statusSortKey: String { status.rawValue }
    var activityIDSortKey: String { activityID?.uuidString ?? "" }
    var projectIDSortKey: String { projectID?.uuidString ?? "" }
}

private struct ActionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let action: ProjectAction?

    @State private var title: String
    @State private var details: String
    @State private var priority: ActionPriority
    @State private var status: ActionStatus
    @State private var dueDate: Date
    @State private var flow: ActionFlow
    @State private var projectID: UUID?
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    init(action: ProjectAction?) {
        self.action = action
        _title = State(initialValue: action?.title ?? "")
        _details = State(initialValue: action?.details ?? "")
        _priority = State(initialValue: action?.priority ?? .minor)
        _status = State(initialValue: action?.status ?? .todo)
        _dueDate = State(initialValue: action?.dueDate ?? Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now)
        _flow = State(initialValue: action?.flow ?? .manuel)
        _projectID = State(initialValue: action?.projectID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Métadonnées obligatoires") {
                    TextField("Titre", text: $title)

                    Picker("Priorité", selection: $priority) {
                        ForEach(ActionPriority.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }

                    Picker("Statut", selection: $status) {
                        ForEach(ActionStatus.allCases) { value in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(value.tintColor)
                                    .frame(width: 9, height: 9)
                                Text(value.label)
                            }
                            .tag(value)
                        }
                    }

                    DatePicker("Date d'échéance", selection: $dueDate, displayedComponents: [.date])

                    Picker("Flux", selection: $flow) {
                        ForEach(ActionFlow.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }

                    Picker("Projet", selection: $projectID) {
                        Text("Sans projet")
                            .tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }

                    if appState.resolvedPrimaryProjectID(in: store) == nil {
                        Text("Aucun Projet Principal défini: sélection projet manuelle.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Projet principal propagé automatiquement, modifiable si nécessaire.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Description détaillée") {
                    TextEditor(text: $details)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle(action == nil ? "Nouvelle action PM" : "Modifier l'action PM")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action == nil ? "Créer" : "Enregistrer") {
                        save()
                    }
                }
            }
            .alert("Validation", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if $0 == false { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
        .frame(minWidth: 660, minHeight: 520)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if canSave {
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

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var snapshot: String {
        [
            title,
            details,
            priority.rawValue,
            status.rawValue,
            String(dueDate.timeIntervalSinceReferenceDate),
            flow.rawValue,
            projectID?.uuidString ?? ""
        ].joined(separator: "|")
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private func captureInitialSnapshotIfNeeded() {
        if initialSnapshot == nil {
            initialSnapshot = snapshot
        }
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDismissConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedTitle.isEmpty == false else {
            validationMessage = "Le titre est obligatoire."
            return
        }

        guard cleanedDetails.isEmpty == false else {
            validationMessage = "La description détaillée est obligatoire."
            return
        }

        if let action {
            store.updateAction(
                actionID: action.id,
                title: cleanedTitle,
                details: cleanedDetails,
                priority: priority,
                dueDate: dueDate,
                flow: flow,
                projectID: projectID,
                status: status
            )
            appState.openAction(action.id)
        } else {
            let createdActionID = store.addAction(
                title: cleanedTitle,
                details: cleanedDetails,
                priority: priority,
                status: status,
                dueDate: dueDate,
                flow: flow,
                projectID: projectID
            )
            appState.openAction(createdActionID)
        }

        dismiss()
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard action == nil, projectID == nil else { return }
        projectID = appState.resolvedPrimaryProjectID(in: store)
    }
}

private enum ActionEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let actionID):
            "edit-\(actionID.uuidString)"
        }
    }

    @MainActor
    func action(in store: SamouraiStore) -> ProjectAction? {
        switch self {
        case .create:
            nil
        case .edit(let actionID):
            store.action(with: actionID)
        }
    }
}
