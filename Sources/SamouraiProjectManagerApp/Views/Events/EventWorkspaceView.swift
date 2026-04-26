import SwiftUI

struct EventWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var editorContext: EventEditorContext?
    @State private var eventPendingDeletion: ProjectEvent?
    @State private var selectedEventIDs: Set<UUID> = []
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "events"
    @State private var isShowingDeleteConfirmation = false
    @State private var sortOrder: [KeyPathComparator<ProjectEvent>] = [
        .init(\.happenedAt, order: .reverse)
    ]

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 760, sidebarIdealWidth: 900, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("Événements projet"))
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d événement(s) affiché(s)", filteredEvents.count, scopedEvents.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedEventIDs.isEmpty == false {
                        Button {
                            if let selectedEventID = selectedEventIDs.singleSelection {
                                editorContext = .edit(selectedEventID)
                            }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(selectedEventIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedEventIDs.count > 1
                                    ? appState.localizedFormat("Supprimer (%d)", selectedEventIDs.count)
                                    : appState.localized("Supprimer"),
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button(appState.localizedFormat("Exporter la vue (%d)", filteredEvents.count)) {
                            prepareExport(events: filteredEvents, filenameSuffix: "vue")
                        }
                        .disabled(filteredEvents.isEmpty)

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedEventsForExport.count)) {
                            prepareExport(events: selectedEventsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedEventsForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create
                    } label: {
                        Label(localized("Nouvel événement"), systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche texte (titre, détails, source, projet, ressources)"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedEvents.isEmpty {
                    ContentUnavailableView(
                        "Aucun événement",
                        systemImage: "bell.slash",
                        description: Text(localized("Ajoute manuellement les événements pour constituer l'historique centralisé du projet."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEvents.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(localized("Ajuste la recherche pour retrouver un événement existant."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredEvents, selection: $selectedEventIDs, sortOrder: $sortOrder) {
                        TableColumnForEach(activeTableColumns) { column in
                            switch column {
                            case .happenedAt:
                                TableColumn(appState.localized(column.label), value: \.happenedAt) { event in
                                    Text(event.happenedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .width(min: 160, ideal: 190)

                            case .priority:
                                TableColumn(appState.localized(column.label), value: \.prioritySortWeight) { event in
                                    Picker(
                                        "Priorité",
                                        selection: Binding(
                                            get: { event.priority },
                                            set: {
                                                store.updateEvent(
                                                    eventID: event.id,
                                                    title: event.title,
                                                    details: event.details,
                                                    source: event.source,
                                                    priority: $0,
                                                    happenedAt: event.happenedAt,
                                                    projectID: event.projectID,
                                                    resourceIDs: event.resourceIDs
                                                )
                                            }
                                        )
                                    ) {
                                        ForEach(EventPriority.allCases) { priority in
                                            Text(priority.label.appLocalized(language: appState.interfaceLanguage)).tag(priority)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                                .width(min: 110, ideal: 120)

                            case .title:
                                TableColumn(appState.localized(column.label), value: \.displayTitle) { event in
                                    TextField(
                                        "Événement",
                                        text: Binding(
                                            get: { event.title },
                                            set: {
                                                store.updateEvent(
                                                    eventID: event.id,
                                                    title: $0,
                                                    details: event.details,
                                                    source: event.source,
                                                    priority: event.priority,
                                                    happenedAt: event.happenedAt,
                                                    projectID: event.projectID,
                                                    resourceIDs: event.resourceIDs
                                                )
                                            }
                                        )
                                    )
                                    .textFieldStyle(.plain)
                                    .fontWeight(.medium)
                                }
                                .width(min: 220, ideal: 320)

                            case .source:
                                TableColumn(appState.localized(column.label), value: \.sourceSortKey) { event in
                                    Text(event.hasSource ? event.source : "-")
                                        .foregroundStyle(event.hasSource ? .primary : .secondary)
                                }
                                .width(min: 180, ideal: 250)

                            case .project:
                                TableColumn(appState.localized(column.label), value: \.projectIDSortKey) { event in
                                    Text(store.projectName(for: event.projectID))
                                }
                                .width(min: 150, ideal: 220)

                            case .resources:
                                TableColumn(appState.localized(column.label), value: \.resourceCount) { event in
                                    let names = store.resourceNames(for: event.resourceIDs)
                                    Text(names.isEmpty ? "-" : names.joined(separator: ", "))
                                        .lineLimit(2)
                                }
                                .width(min: 200, ideal: 320)
                            }
                        }
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
                EventEditorSheet(event: context.event(in: store))
            }
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert(localized("Supprimer l'événement"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
                if selectedEventIDs.isEmpty == false {
                    for eventID in selectedEventIDs {
                        store.deleteEvent(eventID: eventID)
                    }
                    selectedEventIDs.removeAll()
                    appState.selectedEventID = nil
                } else if let pending = eventPendingDeletion {
                    store.deleteEvent(eventID: pending.id)
                }
                eventPendingDeletion = nil
            }
            Button(localized("Annuler"), role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                appState.localized(
                    selectedEventIDs.count > 1
                    ? "Ces événements seront supprimés du suivi projet."
                    : "Cet événement sera supprimé du suivi projet."
                )
            )
        }
        .onChange(of: selectedEventIDs) { _, newSelection in
            appState.selectedEventID = newSelection.singleSelection
        }
        .onChange(of: appState.selectedEventID) { _, newID in
            guard let newID else { return }
            if selectedEventIDs != [newID] {
                selectedEventIDs = [newID]
            }
        }
        .onChange(of: store.events.map(\.id)) { _, eventIDs in
            let existingIDs = Set(eventIDs)
            selectedEventIDs = selectedEventIDs.intersection(existingIDs)
            appState.selectedEventID = selectedEventIDs.singleSelection
        }
    }

    private var activeTableColumns: [EventTableColumn] {
        appState
            .orderedVisibleTableColumnIDs(for: .events)
            .compactMap(EventTableColumn.init(rawValue:))
    }

    private var filteredEvents: [ProjectEvent] {
        let baseEvents = scopedEvents
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return baseEvents.sorted(using: sortOrder) }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return baseEvents.sorted(using: sortOrder) }

        return baseEvents.filter { event in
            let resourceNames = store.resourceNames(for: event.resourceIDs)
            let searchableValues: [String] = [
                event.title,
                event.details,
                event.source,
                event.priority.label.appLocalized(language: appState.interfaceLanguage),
                store.projectName(for: event.projectID),
                event.happenedAt.formatted(date: .abbreviated, time: .shortened)
            ] + resourceNames

            let normalizedValues = searchableValues.map(normalize)
            return terms.allSatisfy { term in
                normalizedValues.contains(where: { $0.contains(term) })
            }
        }
        .sorted(using: sortOrder)
    }

    private var scopedEvents: [ProjectEvent] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.events.filter { $0.projectID == primaryProjectID }
        }
        return store.events
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedEvent: ProjectEvent? {
        guard let selectedEventID = selectedEventIDs.singleSelection else { return nil }
        return store.event(with: selectedEventID)
    }

    private var selectedEventsForExport: [ProjectEvent] {
        filteredEvents.filter { selectedEventIDs.contains($0.id) }
    }

    private func prepareExport(events: [ProjectEvent], filenameSuffix: String) {
        guard events.isEmpty == false else { return }
        let headers = ["DateHeure", "Priorite", "Titre", "Source", "Projet", "Ressources"]
            .map { appState.localized($0) }
        let rows = events.map { event in
            [
                event.happenedAt.formatted(date: .abbreviated, time: .shortened),
                event.priority.label.appLocalized(language: appState.interfaceLanguage),
                event.displayTitle,
                event.source,
                store.projectName(for: event.projectID),
                store.resourceNames(for: event.resourceIDs).joined(separator: " | ")
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-evenements-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private extension ProjectEvent {
    var prioritySortWeight: Int { priority.sortWeight }
    var sourceSortKey: String { source.trimmingCharacters(in: .whitespacesAndNewlines) }
    var projectIDSortKey: String { projectID?.uuidString ?? "" }
    var resourceCount: Int { resourceIDs.count }
}

private struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let event: ProjectEvent?

    @State private var title: String
    @State private var details: String
    @State private var source: String
    @State private var priority: EventPriority
    @State private var happenedAt: Date
    @State private var projectID: UUID?
    @State private var selectedResourceIDs: Set<UUID>
    @State private var resourceSearchText = ""
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    init(event: ProjectEvent?) {
        self.event = event
        _title = State(initialValue: event?.title ?? "")
        _details = State(initialValue: event?.details ?? "")
        _source = State(initialValue: event?.source ?? "")
        _priority = State(initialValue: event?.priority ?? .minor)
        _happenedAt = State(initialValue: event?.happenedAt ?? .now)
        _projectID = State(initialValue: event?.projectID)
        _selectedResourceIDs = State(initialValue: Set(event?.resourceIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Informations")) {
                    TextField(localized("Titre de l'événement"), text: $title)

                    DatePicker(localized("Date et heure"), selection: $happenedAt)

                    Picker(localized("Priorité"), selection: $priority) {
                        ForEach(EventPriority.allCases) { value in
                            Text(value.label.appLocalized(language: appState.interfaceLanguage)).tag(value)
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

                    TextField(localized("Source (email, réunion, chat, directive, ...)"), text: $source)
                }

                Section(localized("Ressources associées")) {
                    TextField(localized("Filtrer les ressources"), text: $resourceSearchText)
                        .textFieldStyle(.roundedBorder)

                    if filteredResources.isEmpty {
                        Text(localized("Aucune ressource"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredResources) { resource in
                            Button {
                                toggleResourceSelection(resource.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedResourceIDs.contains(resource.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedResourceIDs.contains(resource.id) ? Color.accentColor : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(resource.displayName)
                                        Text(resource.displayPrimaryRole)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(localized("Détails")) {
                    TextEditor(text: $details)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle(appState.localized(event == nil ? "Nouvel événement" : "Modifier l'événement"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(event == nil ? "Créer" : "Enregistrer")) {
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
        .frame(minWidth: 700, minHeight: 620)
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

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var snapshot: String {
        [
            title,
            details,
            source,
            priority.rawValue,
            String(happenedAt.timeIntervalSinceReferenceDate),
            projectID?.uuidString ?? "",
            selectedResourceIDs.map(\.uuidString).sorted().joined(separator: ","),
            resourceSearchText
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

    private var filteredResources: [Resource] {
        let query = resourceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return store.resources }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return store.resources.filter { resource in
            let searchable = [resource.displayName, resource.displayPrimaryRole, resource.email]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return searchable.contains(normalizedQuery)
        }
    }

    private func toggleResourceSelection(_ resourceID: UUID) {
        if selectedResourceIDs.contains(resourceID) {
            selectedResourceIDs.remove(resourceID)
        } else {
            selectedResourceIDs.insert(resourceID)
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedTitle.isEmpty == false else {
            validationMessage = "Le titre est obligatoire."
            return
        }

        let sortedResourceIDs = store.resources
            .map(\.id)
            .filter { selectedResourceIDs.contains($0) }

        if let event {
            store.updateEvent(
                eventID: event.id,
                title: cleanedTitle,
                details: details,
                source: source,
                priority: priority,
                happenedAt: happenedAt,
                projectID: projectID,
                resourceIDs: sortedResourceIDs
            )
            appState.openEvent(event.id)
        } else {
            let createdEventID = store.addEvent(
                title: cleanedTitle,
                details: details,
                source: source,
                priority: priority,
                happenedAt: happenedAt,
                projectID: projectID,
                resourceIDs: sortedResourceIDs
            )
            appState.openEvent(createdEventID)
        }

        dismiss()
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard event == nil, projectID == nil else { return }
        projectID = appState.resolvedPrimaryProjectID(in: store)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private enum EventEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let eventID):
            "edit-\(eventID.uuidString)"
        }
    }

    @MainActor
    func event(in store: SamouraiStore) -> ProjectEvent? {
        switch self {
        case .create:
            nil
        case .edit(let eventID):
            store.event(with: eventID)
        }
    }
}

private enum EventTableColumn: String, CaseIterable, Identifiable, Hashable {
    case happenedAt
    case priority
    case title
    case source
    case project
    case resources

    var id: String { rawValue }

    var label: String {
        AppTableID.events.columnTitle(for: rawValue)
    }
}
