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
    @State private var expandedActionIDs: Set<UUID> = []

    private enum Col {
        static let done: CGFloat = 34
        static let status: CGFloat = 145
        static let flow: CGFloat = 170
        static let priority: CGFloat = 120
        static let activity: CGFloat = 200
        static let project: CGFloat = 200
        static let dueDate: CGFloat = 130
        static let createdAt: CGFloat = 170
        static let expand: CGFloat = 28
    }

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
                    actionsTable
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
            expandedActionIDs = expandedActionIDs.intersection(existingIDs)
            appState.selectedActionID = selectedActionIDs.singleSelection
        }
    }

    private var actionsTable: some View {
        VStack(spacing: 0) {
            actionsHeader
            Divider()
            List(filteredActions, selection: $selectedActionIDs) { action in
                actionRow(for: action)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.visible)
            }
            .listStyle(.inset)
            .focusable()
            .onKeyPress(.space) {
                guard let id = selectedActionIDs.singleSelection else { return .ignored }
                withAnimation(.easeInOut(duration: 0.18)) { toggleExpansion(id) }
                return .handled
            }
            .scrollIndicators(.visible)
        }
    }

    @ViewBuilder
    private var actionsHeader: some View {
        HStack(spacing: 8) {
            ForEach(activeTableColumns) { column in
                actionHeaderCell(for: column)
            }
            Spacer().frame(width: Col.expand)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func actionHeaderCell(for column: ActionTableColumn) -> some View {
        switch column {
        case .done:
            Spacer().frame(width: Col.done)
        case .status:
            ActionSortHeader(label: column.label, comparator: .init(\.statusSortKey), sortOrder: $sortOrder)
                .frame(width: Col.status, alignment: .leading)
        case .flow:
            ActionSortHeader(label: column.label, comparator: .init(\.flowSortKey), sortOrder: $sortOrder)
                .frame(width: Col.flow, alignment: .leading)
        case .priority:
            ActionSortHeader(label: column.label, comparator: .init(\.prioritySortWeight, order: .reverse), sortOrder: $sortOrder)
                .frame(width: Col.priority, alignment: .leading)
        case .title:
            ActionSortHeader(label: column.label, comparator: .init(\.displayTitle), sortOrder: $sortOrder)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .activity:
            ActionSortHeader(label: column.label, comparator: .init(\.activityIDSortKey), sortOrder: $sortOrder)
                .frame(width: Col.activity, alignment: .leading)
        case .project:
            ActionSortHeader(label: column.label, comparator: .init(\.projectIDSortKey), sortOrder: $sortOrder)
                .frame(width: Col.project, alignment: .leading)
        case .dueDate:
            ActionSortHeader(label: column.label, comparator: .init(\.dueDate, order: .reverse), sortOrder: $sortOrder)
                .frame(width: Col.dueDate, alignment: .leading)
        case .createdAt:
            ActionSortHeader(label: column.label, comparator: .init(\.createdAt, order: .reverse), sortOrder: $sortOrder)
                .frame(width: Col.createdAt, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actionRow(for action: ProjectAction) -> some View {
        let isExpanded = expandedActionIDs.contains(action.id)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(activeTableColumns) { column in
                    actionRowCell(for: column, action: action)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { toggleExpansion(action.id) }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                        .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(width: Col.expand)
                .help(historyHint(for: action))
            }
            .frame(minHeight: 32)

            if isExpanded {
                ActionHistoryInlinePanel(actionID: action.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    @ViewBuilder
    private func actionRowCell(for column: ActionTableColumn, action: ProjectAction) -> some View {
        switch column {
        case .done:
            Toggle(
                "Terminée",
                isOn: Binding(
                    get: { action.isDone },
                    set: { store.markActionDone(actionID: action.id, isDone: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .frame(width: Col.done)

        case .status:
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
            .frame(width: Col.status, alignment: .leading)

        case .flow:
            Label(action.flow.label, systemImage: action.flow.systemImage)
                .frame(width: Col.flow, alignment: .leading)
                .lineLimit(1)

        case .priority:
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
            .frame(width: Col.priority, alignment: .leading)

        case .title:
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
            .frame(maxWidth: .infinity, alignment: .leading)

        case .activity:
            Group {
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
            .frame(width: Col.activity, alignment: .leading)

        case .project:
            Text(store.projectName(for: action.projectID))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Col.project, alignment: .leading)

        case .dueDate:
            Text(action.dueDate.formatted(date: .abbreviated, time: .omitted))
                .frame(width: Col.dueDate, alignment: .leading)

        case .createdAt:
            Text(action.createdAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
                .frame(width: Col.createdAt, alignment: .leading)
        }
    }

    private func toggleExpansion(_ id: UUID) {
        if expandedActionIDs.contains(id) {
            expandedActionIDs.remove(id)
        } else {
            expandedActionIDs.insert(id)
        }
    }

    private func historyHint(for action: ProjectAction) -> String {
        let count = action.historyEntries.count
        if count == 0 { return "Aucune entrée d'historique" }
        return "Afficher le journal (\(count) entrée\(count > 1 ? "s" : ""))"
    }

    private var activeTableColumns: [ActionTableColumn] {
        appState
            .orderedVisibleTableColumnIDs(for: .actions)
            .compactMap(ActionTableColumn.init(rawValue:))
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
    var isDoneSortKey: Int { isDone ? 1 : 0 }
    var flowSortKey: String { flow.rawValue }
    var prioritySortWeight: Int { priority.sortWeight }
    var statusSortKey: String { status.rawValue }
    var activityIDSortKey: String { activityID?.uuidString ?? "" }
    var projectIDSortKey: String { projectID?.uuidString ?? "" }
}

private struct ActionSortHeader: View {
    let label: String
    let comparator: KeyPathComparator<ProjectAction>
    @Binding var sortOrder: [KeyPathComparator<ProjectAction>]

    private var isActive: Bool {
        sortOrder.first?.keyPath == comparator.keyPath
    }

    var body: some View {
        Button {
            if isActive, var first = sortOrder.first {
                first.order = first.order == .forward ? .reverse : .forward
                sortOrder = [first]
            } else {
                sortOrder = [comparator]
            }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                    .font(.caption.weight(.medium))
                if isActive {
                    Image(systemName: sortOrder.first?.order == .forward ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionHistoryInlinePanel: View {
    @Environment(SamouraiStore.self) private var store
    let actionID: UUID

    var body: some View {
        let entries = store.action(with: actionID)?.historyEntriesChronological ?? []

        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.top, 4)

            if entries.isEmpty {
                Text("Aucune entrée d'historique pour cette action.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
            } else {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: entry.kind.symbolName)
                            .font(.caption)
                            .foregroundStyle(entry.kind == .manual ? Color.accentColor : Color.secondary)
                            .frame(width: 14)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.text)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Text(entry.kind.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
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
    @State private var status: ActionStatus
    @State private var dueDate: Date
    @State private var flow: ActionFlow
    @State private var projectID: UUID?
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false
    @State private var newCommentText: String = ""

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
                Section {
                    TextField("Titre", text: $title)

                    DatePicker("Date d'échéance", selection: $dueDate, displayedComponents: [.date])

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description détaillée")
                            .foregroundStyle(.secondary)
                        TextEditor(text: $details)
                            .frame(minHeight: 140)
                    }

                    severitySlider

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

                    if action != nil {
                        Picker("Flux", selection: $flow) {
                            ForEach(ActionFlow.allCases) { value in
                                Text(value.label).tag(value)
                            }
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

                if let action {
                    historySection(for: action.id)
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

    private var severitySlider: some View {
        let binding = Binding<Double>(
            get: { Double(priority.severityLevel) },
            set: { priority = ActionPriority(severityLevel: Int($0.rounded())) ?? priority }
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sévérité")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(priority.severityColor)
                        .frame(width: 10, height: 10)
                    Text(priority.label)
                        .fontWeight(.medium)
                        .foregroundStyle(priority.severityColor)
                }
            }

            Slider(value: binding, in: 1...4, step: 1)
                .tint(priority.severityColor)

            HStack {
                ForEach(ActionPriority.allCases) { level in
                    Text(level.label)
                        .font(.caption2)
                        .foregroundStyle(level == priority ? level.severityColor : .secondary)
                        .frame(maxWidth: .infinity, alignment: alignment(for: level))
                }
            }
        }
    }

    private func alignment(for level: ActionPriority) -> Alignment {
        switch level {
        case .trivial:  .leading
        case .critical: .trailing
        default:        .center
        }
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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

    @ViewBuilder
    private func historySection(for actionID: UUID) -> some View {
        let currentAction = store.action(with: actionID)
        let entries = currentAction?.historyEntriesChronological ?? []

        Section("Historique") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Ajouter un commentaire", text: $newCommentText, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Ajouter au journal") {
                        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else { return }
                        store.addActionComment(actionID: actionID, text: trimmed)
                        newCommentText = ""
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if entries.isEmpty {
                Text("Aucune entrée d'historique pour le moment.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.kind.symbolName)
                            .foregroundStyle(entry.kind == .manual ? Color.accentColor : Color.secondary)
                            .frame(width: 18)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text)
                                .font(.callout)
                            HStack(spacing: 6) {
                                Text(entry.kind.label)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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

private enum ActionTableColumn: String, CaseIterable, Identifiable, Hashable {
    case done
    case status
    case flow
    case priority
    case title
    case activity
    case project
    case dueDate
    case createdAt

    var id: String { rawValue }

    var label: String {
        AppTableID.actions.columnTitle(for: rawValue)
    }
}
