import SwiftUI

struct DecisionWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var editorContext: DecisionEditorContext?
    @State private var decisionPendingDeletion: ProjectDecision?
    @State private var newCommentAuthor = ""
    @State private var newCommentBody = ""
    @State private var commentValidationMessage: String?
    @State private var selectedDecisionIDs: Set<UUID> = []
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "decisions"
    @State private var isShowingDeleteConfirmation = false
    @State private var sortOrder: [KeyPathComparator<ProjectDecision>] = [
        .init(\.sequenceNumber, order: .reverse)
    ]

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 900, sidebarIdealWidth: 1050, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Registre des décisions")
                            .font(.title2.weight(.semibold))
                        Text("\(filteredDecisions.count) / \(scopedDecisions.count) décision(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedDecisionIDs.isEmpty == false {
                        Button {
                            if let selectedDecisionID = selectedDecisionIDs.singleSelection {
                                editorContext = .edit(selectedDecisionID)
                            }
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .disabled(selectedDecisionIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedDecisionIDs.count > 1 ? "Supprimer (\(selectedDecisionIDs.count))" : "Supprimer",
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button("Exporter la vue (\(filteredDecisions.count))") {
                            prepareExport(decisions: filteredDecisions, filenameSuffix: "vue")
                        }
                        .disabled(filteredDecisions.isEmpty)

                        Button("Exporter la sélection (\(selectedDecisionsForExport.count))") {
                            prepareExport(decisions: selectedDecisionsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedDecisionsForExport.isEmpty)
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create
                    } label: {
                        Label("Nouvelle décision", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField("Recherche (titre, statut, commentaires, réunions, événements)", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedDecisions.isEmpty {
                    ContentUnavailableView(
                        "Aucune décision formelle",
                        systemImage: "scale.3d",
                        description: Text("Consigne les décisions majeures et leurs itérations pour obtenir une traçabilité complète.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredDecisions.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Ajuste la recherche pour retrouver une décision.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredDecisions, selection: $selectedDecisionIDs, sortOrder: $sortOrder) {
                        TableColumn("Ref", value: \.sequenceNumber) { decision in
                            Text("D-\(decision.sequenceNumber)")
                                .monospacedDigit()
                        }
                        .width(min: 70, ideal: 80)

                        TableColumn("Statut", value: \.statusSortKey) { decision in
                            Picker(
                                "Statut",
                                selection: Binding(
                                    get: { decision.status },
                                    set: {
                                        store.updateDecision(
                                            decisionID: decision.id,
                                            title: decision.title,
                                            details: decision.details,
                                            status: $0,
                                            projectID: decision.projectID,
                                            meetingIDs: decision.meetingIDs,
                                            eventIDs: decision.eventIDs,
                                            impactedResourceIDs: decision.impactedResourceIDs,
                                            changeSummary: "Mise à jour rapide du statut"
                                        )
                                    }
                                )
                            ) {
                                ForEach(DecisionStatus.allCases) { status in
                                    Text(status.shortLabel).tag(status)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .width(min: 130, ideal: 160)

                        TableColumn("Décision", value: \.displayTitle) { decision in
                            TextField(
                                "Décision",
                                text: Binding(
                                    get: { decision.title },
                                    set: {
                                        store.updateDecision(
                                            decisionID: decision.id,
                                            title: $0,
                                            details: decision.details,
                                            status: decision.status,
                                            projectID: decision.projectID,
                                            meetingIDs: decision.meetingIDs,
                                            eventIDs: decision.eventIDs,
                                            impactedResourceIDs: decision.impactedResourceIDs,
                                            changeSummary: "Mise à jour rapide du titre"
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                            .fontWeight(.medium)
                        }
                        .width(min: 240, ideal: 340)

                        TableColumn("Projet", value: \.projectIDSortKey) { decision in
                            Text(store.projectName(for: decision.projectID))
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Réunions liées", value: \.meetingCount) { decision in
                            Text("\(decision.meetingIDs.count)")
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Événements liés", value: \.eventCount) { decision in
                            Text("\(decision.eventIDs.count)")
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("Révisions", value: \.revisionCount) { decision in
                            Text("\(decision.history.count)")
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Commentaires", value: \.commentCount) { decision in
                            Text("\(decision.comments.count)")
                        }
                        .width(min: 110, ideal: 130)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .frame(minWidth: 900, idealWidth: 1050)

        } detail: {
            EmptyView()
        }
        .sheet(isPresented: Binding(
            get: { editorContext != nil },
            set: { if $0 == false { editorContext = nil } }
        )) {
            if let context = editorContext {
                DecisionEditorSheet(decision: context.decision(in: store))
            }
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert("Supprimer la décision", isPresented: $isShowingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if selectedDecisionIDs.isEmpty == false {
                    for decisionID in selectedDecisionIDs {
                        store.deleteDecision(decisionID: decisionID)
                    }
                    selectedDecisionIDs.removeAll()
                    appState.selectedDecisionID = nil
                } else if let pending = decisionPendingDeletion {
                    store.deleteDecision(decisionID: pending.id)
                }
                decisionPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                selectedDecisionIDs.count > 1
                ? "Ces décisions seront retirées du registre de gouvernance."
                : "La décision sera retirée du registre de gouvernance."
            )
        }
        .alert("Commentaire", isPresented: Binding(
            get: { commentValidationMessage != nil },
            set: { if $0 == false { commentValidationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(commentValidationMessage ?? "")
        }
        .onChange(of: selectedDecisionIDs) { _, newSelection in
            appState.selectedDecisionID = newSelection.singleSelection
        }
        .onChange(of: appState.selectedDecisionID) { _, newID in
            guard let newID else { return }
            if selectedDecisionIDs != [newID] {
                selectedDecisionIDs = [newID]
            }
        }
        .onChange(of: store.decisions.map(\.id)) { _, decisionIDs in
            let existingIDs = Set(decisionIDs)
            selectedDecisionIDs = selectedDecisionIDs.intersection(existingIDs)
            appState.selectedDecisionID = selectedDecisionIDs.singleSelection
        }
    }

    private var filteredDecisions: [ProjectDecision] {
        let baseDecisions = scopedDecisions
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return baseDecisions.sorted(using: sortOrder) }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return baseDecisions.sorted(using: sortOrder) }

        return baseDecisions.filter { decision in
            var searchableValues: [String] = [
                decision.title,
                decision.details,
                decision.status.label,
                decision.status.shortLabel,
                "D-\(decision.sequenceNumber)",
                store.projectName(for: decision.projectID)
            ]
            searchableValues.append(contentsOf: decision.comments.map(\.body))
            searchableValues.append(contentsOf: decision.history.map(\.summary))
            searchableValues.append(contentsOf: decision.meetingIDs.compactMap { store.meeting(with: $0)?.displayTitle })
            searchableValues.append(contentsOf: decision.eventIDs.compactMap { store.event(with: $0)?.displayTitle })
            searchableValues.append(contentsOf: decision.impactedResourceIDs.compactMap { store.resource(with: $0)?.displayName })

            let normalizedValues = searchableValues.map(normalize)
            return terms.allSatisfy { term in
                normalizedValues.contains(where: { $0.contains(term) })
            }
        }
        .sorted(using: sortOrder)
    }

    private var scopedDecisions: [ProjectDecision] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.decisions.filter { $0.projectID == primaryProjectID }
        }
        return store.decisions
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedDecision: ProjectDecision? {
        guard let selectedDecisionID = selectedDecisionIDs.singleSelection else { return nil }
        return store.decision(with: selectedDecisionID)
    }

    private var selectedDecisionsForExport: [ProjectDecision] {
        filteredDecisions.filter { selectedDecisionIDs.contains($0.id) }
    }

    private func prepareExport(decisions: [ProjectDecision], filenameSuffix: String) {
        guard decisions.isEmpty == false else { return }
        let headers = ["Reference", "Statut", "Decision", "Projet", "Revisions", "Commentaires"]
        let rows = decisions.map { decision in
            [
                "D-\(decision.sequenceNumber)",
                decision.status.shortLabel,
                decision.displayTitle,
                store.projectName(for: decision.projectID),
                String(decision.history.count),
                String(decision.comments.count)
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-decisions-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }

    private func addComment(to decisionID: UUID) {
        let cleanedBody = newCommentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedBody.isEmpty == false else {
            commentValidationMessage = "Le commentaire ne peut pas être vide."
            return
        }

        store.addDecisionComment(decisionID: decisionID, author: newCommentAuthor, body: cleanedBody)
        newCommentBody = ""
    }
}

private extension ProjectDecision {
    var statusSortKey: String { status.rawValue }
    var projectIDSortKey: String { projectID?.uuidString ?? "" }
    var meetingCount: Int { meetingIDs.count }
    var eventCount: Int { eventIDs.count }
    var revisionCount: Int { history.count }
    var commentCount: Int { comments.count }
}

private struct DecisionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let decision: ProjectDecision?

    @State private var title: String
    @State private var details: String
    @State private var status: DecisionStatus
    @State private var projectID: UUID?
    @State private var selectedMeetingIDs: Set<UUID>
    @State private var selectedEventIDs: Set<UUID>
    @State private var selectedResourceIDs: Set<UUID>
    @State private var changeSummary: String
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    init(decision: ProjectDecision?) {
        self.decision = decision
        _title = State(initialValue: decision?.title ?? "")
        _details = State(initialValue: decision?.details ?? "")
        _status = State(initialValue: decision?.status ?? .proposedUnderReview)
        _projectID = State(initialValue: decision?.projectID)
        _selectedMeetingIDs = State(initialValue: Set(decision?.meetingIDs ?? []))
        _selectedEventIDs = State(initialValue: Set(decision?.eventIDs ?? []))
        _selectedResourceIDs = State(initialValue: Set(decision?.impactedResourceIDs ?? []))
        _changeSummary = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Décision") {
                    TextField("Titre", text: $title)

                    Picker("Statut", selection: $status) {
                        ForEach(DecisionStatus.allCases) { value in
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

                    TextField("Description détaillée", text: $details, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Liens contextuels") {
                    contextToggleSection(title: "Réunions liées", items: store.meetings, selectedIDs: $selectedMeetingIDs) { meeting in
                        "\(meeting.displayTitle) · \(meeting.meetingAt.formatted(date: .abbreviated, time: .shortened))"
                    }

                    contextToggleSection(title: "Événements liés", items: store.events, selectedIDs: $selectedEventIDs) { event in
                        "\(event.displayTitle) · \(event.happenedAt.formatted(date: .abbreviated, time: .shortened))"
                    }

                    contextToggleSection(title: "Ressources impactées", items: store.resources, selectedIDs: $selectedResourceIDs) { resource in
                        "\(resource.displayName) · \(resource.displayPrimaryRole)"
                    }
                }

                Section("Journal de modification") {
                    TextField("Résumé du changement (optionnel)", text: $changeSummary)
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
            .navigationTitle(decision == nil ? "Nouvelle décision" : "Modifier la décision")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(decision == nil ? "Créer" : "Enregistrer") {
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
        .frame(minWidth: 760, minHeight: 780)
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
            status.rawValue,
            projectID?.uuidString ?? "",
            selectedMeetingIDs.map(\.uuidString).sorted().joined(separator: ","),
            selectedEventIDs.map(\.uuidString).sorted().joined(separator: ","),
            selectedResourceIDs.map(\.uuidString).sorted().joined(separator: ","),
            changeSummary
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

    private func contextToggleSection<Item: Identifiable>(
        title: String,
        items: [Item],
        selectedIDs: Binding<Set<UUID>>,
        label: @escaping (Item) -> String
    ) -> some View where Item.ID == UUID {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if items.isEmpty {
                Text("Aucun élément disponible")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Toggle(
                        label(item),
                        isOn: Binding(
                            get: { selectedIDs.wrappedValue.contains(item.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedIDs.wrappedValue.insert(item.id)
                                } else {
                                    selectedIDs.wrappedValue.remove(item.id)
                                }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedTitle.isEmpty == false else {
            validationMessage = "Le titre est obligatoire."
            return
        }

        guard cleanedDetails.isEmpty == false else {
            validationMessage = "La description est obligatoire."
            return
        }

        let orderedMeetingIDs = store.meetings.map(\.id).filter { selectedMeetingIDs.contains($0) }
        let orderedEventIDs = store.events.map(\.id).filter { selectedEventIDs.contains($0) }
        let orderedResourceIDs = store.resources.map(\.id).filter { selectedResourceIDs.contains($0) }

        if let decision {
            store.updateDecision(
                decisionID: decision.id,
                title: cleanedTitle,
                details: cleanedDetails,
                status: status,
                projectID: projectID,
                meetingIDs: orderedMeetingIDs,
                eventIDs: orderedEventIDs,
                impactedResourceIDs: orderedResourceIDs,
                changeSummary: changeSummary
            )
            appState.openDecision(decision.id)
        } else {
            let decisionID = store.addDecision(
                title: cleanedTitle,
                details: cleanedDetails,
                status: status,
                projectID: projectID,
                meetingIDs: orderedMeetingIDs,
                eventIDs: orderedEventIDs,
                impactedResourceIDs: orderedResourceIDs
            )
            appState.openDecision(decisionID)
        }

        dismiss()
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard decision == nil, projectID == nil else { return }
        projectID = appState.resolvedPrimaryProjectID(in: store)
    }
}

private enum DecisionEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let decisionID):
            "edit-\(decisionID.uuidString)"
        }
    }

    @MainActor
    func decision(in store: SamouraiStore) -> ProjectDecision? {
        switch self {
        case .create:
            nil
        case .edit(let decisionID):
            store.decision(with: decisionID)
        }
    }
}
