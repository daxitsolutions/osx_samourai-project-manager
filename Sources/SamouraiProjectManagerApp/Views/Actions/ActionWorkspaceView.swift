import SwiftUI

struct ActionWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var selectedFlow: ActionFlowFilter = .all
    @State private var editorContext: ActionEditorContext?
    @State private var actionPendingDeletion: ProjectAction?

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liste d'actions PM")
                            .font(.title2.weight(.semibold))
                        Text("\(filteredActions.count) / \(scopedActions.count) action(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedAction != nil {
                        Button {
                            if let selectedActionID = appState.selectedActionID {
                                editorContext = .edit(selectedActionID)
                            }
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            actionPendingDeletion = selectedAction
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
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
                    Table(filteredActions, selection: $appState.selectedActionID) {
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

                        TableColumn("Flux") { action in
                            Label(action.flow.label, systemImage: action.flow.systemImage)
                        }
                        .width(min: 160, ideal: 170)

                        TableColumn("Priorité") { action in
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

                        TableColumn("Titre") { action in
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

                        TableColumn("Activité") { action in
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

                        TableColumn("Projet") { action in
                            Text(store.projectName(for: action.projectID))
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Échéance") { action in
                            Text(action.dueDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .width(min: 120, ideal: 130)

                        TableColumn("Créée le") { action in
                            Text(action.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 150, ideal: 170)
                    }
                }
            }
            .frame(minWidth: 760, idealWidth: 900)

            Group {
                if let action = selectedAction {
                    ActionDetailView(
                        action: action,
                        projectName: store.projectName(for: action.projectID),
                        activityTitle: activityTitle(for: action.activityID),
                        onEdit: { editorContext = .edit(action.id) },
                        onDelete: { actionPendingDeletion = action },
                        onToggleDone: { store.markActionDone(actionID: action.id, isDone: !action.isDone) }
                    )
                } else {
                    ContentUnavailableView(
                        "Sélectionne une action",
                        systemImage: "sidebar.left",
                        description: Text("La fiche détail permet un suivi clair, rapide et centré sur le flux du Chef de Projet.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $editorContext) { context in
            ActionEditorSheet(action: context.action(in: store))
        }
        .alert("Supprimer l'action", isPresented: Binding(
            get: { actionPendingDeletion != nil },
            set: { if $0 == false { actionPendingDeletion = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let pending = actionPendingDeletion {
                    if appState.selectedActionID == pending.id {
                        appState.selectedActionID = nil
                    }
                    store.deleteAction(actionID: pending.id)
                }
                actionPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                actionPendingDeletion = nil
            }
        } message: {
            Text("Cette action sera retirée de la liste proactive du PM.")
        }
        .onChange(of: store.actions.map(\.id)) { _, actionIDs in
            let existingIDs = Set(actionIDs)
            if let selectedActionID = appState.selectedActionID, existingIDs.contains(selectedActionID) == false {
                appState.selectedActionID = nil
            }
        }
    }

    private var filteredActions: [ProjectAction] {
        let flowFilteredActions: [ProjectAction]
        switch selectedFlow {
        case .all:
            flowFilteredActions = scopedActions
        case .incomingLeMans:
            flowFilteredActions = scopedActions.filter { $0.flow == .incomingLeMans }
        case .pushedAutomatic:
            flowFilteredActions = scopedActions.filter { $0.flow == .pushedAutomatic }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return flowFilteredActions }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return flowFilteredActions }

        return flowFilteredActions.filter { action in
            let searchableValues: [String] = [
                action.title,
                action.details,
                action.priority.label,
                action.flow.label,
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
        guard let selectedActionID = appState.selectedActionID else { return nil }
        return store.action(with: selectedActionID)
    }

    private func activityTitle(for activityID: UUID?) -> String {
        guard let activityID, let activity = store.activity(with: activityID) else { return "" }
        return activity.displayTitle
    }
}

private struct ActionDetailView: View {
    let action: ProjectAction
    let projectName: String
    let activityTitle: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(action.displayTitle)
                            .font(.largeTitle.weight(.semibold))

                        HStack(spacing: 14) {
                            Label(action.flow.label, systemImage: action.flow.systemImage)
                            Label(action.priority.label, systemImage: "flag.fill")
                                .foregroundStyle(action.priority.tintColor)
                            if activityTitle.isEmpty == false {
                                Label(activityTitle, systemImage: "calendar.badge.clock")
                            }
                            Label(projectName, systemImage: "folder")
                            Label(action.dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action.isDone ? "Rouvrir" : "Marquer terminée") {
                        onToggleDone()
                    }

                    Button {
                        onEdit()
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Description détaillée")
                        .font(.title3.weight(.semibold))

                    Text(action.details)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Créée le \(action.createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.plus")
                    Label("Modifiée le \(action.updatedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                    Label(action.isDone ? "Statut: Terminée" : "Statut: Ouverte", systemImage: action.isDone ? "checkmark.circle.fill" : "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let action: ProjectAction?

    @State private var title: String
    @State private var details: String
    @State private var priority: ActionPriority
    @State private var dueDate: Date
    @State private var flow: ActionFlow
    @State private var projectID: UUID?
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false

    init(action: ProjectAction?) {
        self.action = action
        _title = State(initialValue: action?.title ?? "")
        _details = State(initialValue: action?.details ?? "")
        _priority = State(initialValue: action?.priority ?? .minor)
        _dueDate = State(initialValue: action?.dueDate ?? Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now)
        _flow = State(initialValue: action?.flow ?? .incomingLeMans)
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
                        dismiss()
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
        .onAppear {
            applyPrimaryProjectDefaultIfNeeded()
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
                projectID: projectID
            )
            appState.openAction(action.id)
        } else {
            let createdActionID = store.addAction(
                title: cleanedTitle,
                details: cleanedDetails,
                priority: priority,
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
