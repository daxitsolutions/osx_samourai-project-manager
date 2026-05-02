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
                        Text(localized("Registre des décisions"))
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d décision(s)", filteredDecisions.count, scopedDecisions.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedDecisionIDs.isEmpty == false {
                        Button {
                            if let selectedDecisionID = selectedDecisionIDs.singleSelection {
                                editorContext = .edit(selectedDecisionID)
                            }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(selectedDecisionIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedDecisionIDs.count > 1
                                    ? appState.localizedFormat("Supprimer (%d)", selectedDecisionIDs.count)
                                    : appState.localized("Supprimer"),
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button(appState.localizedFormat("Exporter la vue (%d)", filteredDecisions.count)) {
                            prepareExport(decisions: filteredDecisions, filenameSuffix: "vue")
                        }
                        .disabled(filteredDecisions.isEmpty)

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedDecisionsForExport.count)) {
                            prepareExport(decisions: selectedDecisionsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedDecisionsForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create
                    } label: {
                        Label(localized("Nouvelle décision"), systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche (titre, statut, commentaires, réunions, événements)"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedDecisions.isEmpty {
                    ContentUnavailableView(
                        "Aucune décision formelle",
                        systemImage: "scale.3d",
                        description: Text(localized("Consigne les décisions majeures et leurs itérations pour obtenir une traçabilité complète."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredDecisions.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(localized("Ajuste la recherche pour retrouver une décision."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredDecisions, selection: $selectedDecisionIDs, sortOrder: $sortOrder) {
                        TableColumnForEach(activeTableColumns) { column in
                            switch column {
                            case .reference:
                                TableColumn(appState.localized(column.label), value: \.sequenceNumber) { decision in
                                    Text("D-\(decision.sequenceNumber)")
                                        .monospacedDigit()
                                }
                                .width(min: 70, ideal: 80)

                            case .status:
                                TableColumn(appState.localized(column.label), value: \.statusSortKey) { decision in
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
                                                    changeSummary: appState.localized("Mise à jour rapide du statut")
                                                )
                                            }
                                        )
                                    ) {
                                        ForEach(DecisionStatus.allCases) { status in
                                            Text(status.shortLabel.appLocalized(language: appState.interfaceLanguage)).tag(status)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                                .width(min: 130, ideal: 160)

                            case .title:
                                TableColumn(appState.localized(column.label), value: \.displayTitle) { decision in
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
                                                    changeSummary: appState.localized("Mise à jour rapide du titre")
                                                )
                                            }
                                        )
                                    )
                                    .textFieldStyle(.plain)
                                    .fontWeight(.medium)
                                }
                                .width(min: 240, ideal: 340)

                            case .project:
                                TableColumn(appState.localized(column.label), value: \.projectIDSortKey) { decision in
                                    Text(store.projectName(for: decision.projectID))
                                }
                                .width(min: 150, ideal: 220)

                            case .meetings:
                                TableColumn(appState.localized(column.label), value: \.meetingCount) { decision in
                                    Text("\(decision.meetingIDs.count)")
                                }
                                .width(min: 90, ideal: 110)

                            case .events:
                                TableColumn(appState.localized(column.label), value: \.eventCount) { decision in
                                    Text("\(decision.eventIDs.count)")
                                }
                                .width(min: 100, ideal: 120)

                            case .revisions:
                                TableColumn(appState.localized(column.label), value: \.revisionCount) { decision in
                                    Text("\(decision.history.count)")
                                }
                                .width(min: 90, ideal: 110)

                            case .comments:
                                TableColumn(appState.localized(column.label), value: \.commentCount) { decision in
                                    Text("\(decision.comments.count)")
                                }
                                .width(min: 110, ideal: 130)
                            }
                        }
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
        .alert(localized("Supprimer la décision"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
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
            Button(localized("Annuler"), role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                appState.localized(
                    selectedDecisionIDs.count > 1
                    ? "Ces décisions seront retirées du registre de gouvernance."
                    : "La décision sera retirée du registre de gouvernance."
                )
            )
        }
        .alert(localized("Commentaire"), isPresented: Binding(
            get: { commentValidationMessage != nil },
            set: { if $0 == false { commentValidationMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(appState.localized(commentValidationMessage ?? ""))
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

    private var activeTableColumns: [DecisionTableColumn] {
        appState
            .orderedVisibleTableColumnIDs(for: .decisions)
            .compactMap(DecisionTableColumn.init(rawValue:))
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
                decision.status.label.appLocalized(language: appState.interfaceLanguage),
                decision.status.shortLabel.appLocalized(language: appState.interfaceLanguage),
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
            .map { appState.localized($0) }
        let rows = decisions.map { decision in
            [
                "D-\(decision.sequenceNumber)",
                decision.status.shortLabel.appLocalized(language: appState.interfaceLanguage),
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
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

private enum DecisionTableColumn: String, CaseIterable, Identifiable, Hashable {
    case reference
    case status
    case title
    case project
    case meetings
    case events
    case revisions
    case comments

    var id: String { rawValue }

    var label: String {
        AppTableID.decisions.columnTitle(for: rawValue)
    }
}
