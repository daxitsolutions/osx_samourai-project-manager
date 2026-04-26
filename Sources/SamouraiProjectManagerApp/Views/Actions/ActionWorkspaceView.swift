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
                        Text(localized("Liste d'actions PM"))
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d action(s)", filteredActions.count, scopedActions.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedActionIDs.isEmpty == false {
                        Button {
                            if let selectedActionID = selectedActionIDs.singleSelection {
                                editorContext = .edit(selectedActionID)
                            }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(selectedActionIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedActionIDs.count > 1
                                    ? appState.localizedFormat("Supprimer (%d)", selectedActionIDs.count)
                                    : appState.localized("Supprimer"),
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button(appState.localizedFormat("Exporter la vue (%d)", filteredActions.count)) {
                            prepareExport(actions: filteredActions, filenameSuffix: "vue")
                        }
                        .disabled(filteredActions.isEmpty)

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedActionsForExport.count)) {
                            prepareExport(actions: selectedActionsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedActionsForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create
                    } label: {
                        Label(localized("Nouvelle action"), systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche (titre, description, priorité, flux)"), text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker(localized("Flux"), selection: $selectedFlow) {
                        ForEach(ActionFlowFilter.allCases) { filter in
                            Text(filter.label.appLocalized(language: appState.interfaceLanguage)).tag(filter)
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
                        description: Text(localized("Saisis les directives reçues pour les convertir en tâches opérationnelles du Chef de Projet."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredActions.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(localized("Ajuste la recherche ou le filtre de flux."))
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
        .alert(localized("Supprimer l'action"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
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
            Button(localized("Annuler"), role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                appState.localized(
                    selectedActionIDs.count > 1
                    ? "Ces actions seront retirées de la liste proactive du PM."
                    : "Cette action sera retirée de la liste proactive du PM."
                )
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
                    Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                        .font(.system(size: 14))
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
                        Text(status.label.appLocalized(language: appState.interfaceLanguage))
                    }
                    .tag(status)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: Col.status, alignment: .leading)

        case .flow:
            Label(action.flow.label.appLocalized(language: appState.interfaceLanguage), systemImage: action.flow.systemImage)
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
                    Text(priority.label.appLocalized(language: appState.interfaceLanguage)).tag(priority)
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
                        Text(localized("Aucune")).tag(Optional<UUID>.none)
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
        if count == 0 { return appState.localized("Ouvrir le journal d'activité") }
        return appState.localizedFormat(
            count == 1 ? "Ouvrir le journal d'activité (%d entrée)" : "Ouvrir le journal d'activité (%d entrées)",
            count
        )
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
                action.priority.label.appLocalized(language: appState.interfaceLanguage),
                action.flow.label.appLocalized(language: appState.interfaceLanguage),
                action.status.label.appLocalized(language: appState.interfaceLanguage),
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
            .map { appState.localized($0) }
        let rows = actions.map { action in
            [
                action.displayTitle,
                action.status.label.appLocalized(language: appState.interfaceLanguage),
                action.priority.label.appLocalized(language: appState.interfaceLanguage),
                action.flow.label.appLocalized(language: appState.interfaceLanguage),
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
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
    @Environment(AppState.self) private var appState

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
                Text(label.appLocalized(language: appState.interfaceLanguage))
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
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store
    let actionID: UUID

    private enum SubCol {
        static let kind: CGFloat = 170
        static let date: CGFloat = 150
    }

    var body: some View {
        let entries = store.action(with: actionID)?.historyEntriesChronological ?? []

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(appState.localized("Journal d'activité"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appState.localizedFormat(entries.count == 1 ? "%d entrée" : "%d entrées", entries.count))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if entries.isEmpty {
                Text(appState.localized("Aucune entrée d'historique pour cette action."))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
            } else {
                HStack(spacing: 8) {
                    Text(localized("Type"))
                        .frame(width: SubCol.kind, alignment: .leading)
                    Text(localized("Description"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(localized("Date"))
                        .frame(width: SubCol.date, alignment: .leading)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider()

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .top, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.kind.symbolName)
                                .font(.caption)
                                .foregroundStyle(entry.kind == .manual ? Color.accentColor : Color.secondary)
                                .frame(width: 14)
                            Text(entry.kind.label.appLocalized(language: appState.interfaceLanguage))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: SubCol.kind, alignment: .leading)

                        Text(entry.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: SubCol.date, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
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
                    TextField(localized("Titre"), text: $title)

                    DatePicker(localized("Date d'échéance"), selection: $dueDate, displayedComponents: [.date])

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("Description détaillée"))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $details)
                            .frame(minHeight: 140)
                    }

                    severitySlider

                    Picker(localized("Statut"), selection: $status) {
                        ForEach(ActionStatus.allCases) { value in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(value.tintColor)
                                    .frame(width: 9, height: 9)
                                Text(value.label.appLocalized(language: appState.interfaceLanguage))
                            }
                            .tag(value)
                        }
                    }

                    if action != nil {
                        Picker(localized("Flux"), selection: $flow) {
                            ForEach(ActionFlow.allCases) { value in
                                Text(value.label.appLocalized(language: appState.interfaceLanguage)).tag(value)
                            }
                        }
                    }

                    Picker(localized("Projet"), selection: $projectID) {
                        Text(localized("Sans projet"))
                            .tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }

                    if appState.resolvedPrimaryProjectID(in: store) == nil {
                        Text(localized("Aucun Projet Principal défini: sélection projet manuelle."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(localized("Projet principal propagé automatiquement, modifiable si nécessaire."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let action {
                    historySection(for: action.id)
                }
            }
            .navigationTitle(appState.localized(action == nil ? "Nouvelle action PM" : "Modifier l'action PM"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(action == nil ? "Créer" : "Enregistrer")) {
                        save()
                    }
                }
            }
            .alert(localized("Validation"), isPresented: Binding(
                get: { validationMessage != nil },
                set: { if $0 == false { validationMessage = nil } }
            )) {
                Button(localized("OK"), role: .cancel) {}
            } message: {
                Text(appState.localized(validationMessage ?? ""))
            }
        }
        .frame(minWidth: 660, minHeight: 520)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if canSave {
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

    private var severitySlider: some View {
        let binding = Binding<Double>(
            get: { Double(priority.severityLevel) },
            set: { priority = ActionPriority(severityLevel: Int($0.rounded())) ?? priority }
        )

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localized("Sévérité"))
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(priority.severityColor)
                        .frame(width: 10, height: 10)
                    Text(priority.label.appLocalized(language: appState.interfaceLanguage))
                        .fontWeight(.medium)
                        .foregroundStyle(priority.severityColor)
                }
            }

            Slider(value: binding, in: 1...4, step: 1)
                .tint(priority.severityColor)

            HStack {
                ForEach(ActionPriority.allCases) { level in
                    Text(level.label.appLocalized(language: appState.interfaceLanguage))
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

        Section(localized("Historique")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(localized("Ajouter un commentaire"), text: $newCommentText, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button(localized("Ajouter au journal")) {
                        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else { return }
                        store.addActionComment(actionID: actionID, text: trimmed)
                        newCommentText = ""
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if entries.isEmpty {
                Text(localized("Aucune entrée d'historique pour le moment."))
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
                                Text(entry.kind.label.appLocalized(language: appState.interfaceLanguage))
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
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
