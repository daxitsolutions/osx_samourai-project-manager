import SwiftUI
import UniformTypeIdentifiers

struct RiskRegisterView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var isShowingFileImporter = false
    @State private var riskEditorContext: RiskRegistryEditorContext?
    @State private var importFeedbackMessage: String?
    @State private var isImporting = false
    @State private var searchText = ""
    @State private var selectedRiskIDs: Set<UUID> = []
    @State private var expandedRiskIDs: Set<UUID> = []
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "risks"
    @State private var sortOrder: [KeyPathComparator<RiskEntry>] = [
        .init(\.severitySortWeight, order: .reverse)
    ]

    private enum Col {
        static let id: CGFloat = 55
        static let project: CGFloat = 110
        static let owner: CGFloat = 100
        static let severity: CGFloat = 88
        static let status: CGFloat = 148
        static let score: CGFloat = 48
        static let expand: CGFloat = 26
    }

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 620, sidebarIdealWidth: 760, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("Registre global des risques"))
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d risque(s) suivi(s)", filteredRisks.count, scopedRisks.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button(appState.localizedFormat("Exporter la vue (%d)", filteredRisks.count)) {
                            prepareExport(risks: filteredRisks, filenameSuffix: "vue")
                        }
                        .disabled(filteredRisks.isEmpty)

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedRisksForExport.count)) {
                            prepareExport(risks: selectedRisksForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedRisksForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    if selectedRiskIDs.isEmpty == false {
                        Button {
                            if let selectedRiskID = selectedRiskIDs.singleSelection {
                                riskEditorContext = .edit(selectedRiskID)
                            }
                        } label: {
                            Label(localized("Modifier"), systemImage: "pencil")
                        }
                        .disabled(selectedRiskIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedRiskIDs.count > 1
                                    ? appState.localizedFormat("Supprimer (%d)", selectedRiskIDs.count)
                                    : appState.localized("Supprimer"),
                                systemImage: "trash"
                            )
                        }
                    }

                    Button {
                        riskEditorContext = .create
                    } label: {
                        Label(localized("Nouveau risque"), systemImage: "plus")
                    }
                    .disabled(store.projects.isEmpty)

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label(localized("Importer"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche (titre, owner, projet, severite, statut)"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedRisks.isEmpty {
                    ContentUnavailableView(
                        "Aucun risque",
                        systemImage: "checkmark.shield",
                        description: Text(localized("Les risques créés ou importés apparaîtront ici."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        riskTableHeader
                        Divider()
                        List(filteredRisks, selection: $selectedRiskIDs) { entry in
                            riskRow(for: entry)
                                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                                .listRowSeparator(.visible)
                        }
                        .listStyle(.inset)
                        .focusable()
                        .onKeyPress(.space) {
                            guard let id = selectedRiskIDs.singleSelection else { return .ignored }
                            withAnimation(.easeInOut(duration: 0.18)) { toggleExpansion(id) }
                            return .handled
                        }
                        .scrollIndicators(.visible)
                    }
                }
            }
            .frame(minWidth: 620, idealWidth: 760)

        } detail: {
            EmptyView()
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "xlsx") ?? .data,
                .commaSeparatedText,
                .tabSeparatedText
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: Binding(
            get: { riskEditorContext != nil },
            set: { if $0 == false { riskEditorContext = nil } }
        )) {
            if let context = riskEditorContext {
                ManualRiskEditorSheet(
                    entry: context.entry(in: store),
                    suggestedProjectID: appState.resolvedPrimaryProjectID(in: store)
                )
            }
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert(localized("Supprimer les risques"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
                for riskID in selectedRiskIDs {
                    deleteRisk(riskID)
                }
                selectedRiskIDs.removeAll()
                appState.selectedRiskID = nil
            }
            Button(localized("Annuler"), role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(appState.localized(selectedRiskIDs.count > 1 ? "Les risques sélectionnés seront supprimés." : "Le risque sélectionné sera supprimé."))
        }
        .alert(localized("Import des risques"), isPresented: Binding(
            get: { importFeedbackMessage != nil },
            set: { if $0 == false { importFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(appState.localized(importFeedbackMessage ?? ""))
        }
        .onChange(of: selectedRiskIDs) { _, newSelection in
            appState.selectedRiskID = newSelection.singleSelection
        }
        .onChange(of: appState.selectedRiskID) { _, newID in
            guard let newID else { return }
            if selectedRiskIDs != [newID] {
                selectedRiskIDs = [newID]
            }
        }
        .onChange(of: store.risks.map(\.risk.id)) { _, ids in
            let existing = Set(ids)
            selectedRiskIDs = selectedRiskIDs.intersection(existing)
            expandedRiskIDs = expandedRiskIDs.intersection(existing)
            appState.selectedRiskID = selectedRiskIDs.singleSelection
        }
        .padding(0)
    }

    // MARK: - Table header

    @ViewBuilder
    private var riskTableHeader: some View {
        HStack(spacing: 8) {
            RiskSortHeader(label: "ID", comparator: .init(\.externalIDSortKey), sortOrder: $sortOrder)
                .frame(width: Col.id, alignment: .leading)
            RiskSortHeader(label: "Titre", comparator: .init(\.titleSortKey), sortOrder: $sortOrder)
                .frame(maxWidth: .infinity, alignment: .leading)
            RiskSortHeader(label: "Projet(s)", comparator: .init(\.projectsSortKey), sortOrder: $sortOrder)
                .frame(width: Col.project, alignment: .leading)
            RiskSortHeader(label: "Assigné à", comparator: .init(\.ownerSortKey), sortOrder: $sortOrder)
                .frame(width: Col.owner, alignment: .leading)
            RiskSortHeader(label: "Sévérité", comparator: .init(\.severitySortWeight, order: .reverse), sortOrder: $sortOrder)
                .frame(width: Col.severity, alignment: .leading)
            RiskSortHeader(label: "Statut", comparator: .init(\.statusSortWeight), sortOrder: $sortOrder)
                .frame(width: Col.status, alignment: .leading)
            RiskSortHeader(label: "Score", comparator: .init(\.scoreSortValue, order: .reverse), sortOrder: $sortOrder)
                .frame(width: Col.score, alignment: .trailing)
            Spacer().frame(width: Col.expand)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Table rows

    @ViewBuilder
    private func riskRow(for entry: RiskEntry) -> some View {
        let isExpanded = expandedRiskIDs.contains(entry.risk.id)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(entry.risk.externalID ?? "-")
                    .frame(width: Col.id, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                TextField(
                    "Titre",
                    text: Binding(
                        get: { entry.risk.displayTitle },
                        set: {
                            store.updateRiskQuick(
                                riskID: entry.risk.id,
                                title: $0,
                                owner: entry.risk.displayOwner,
                                severity: entry.risk.severity,
                                status: entry.risk.riskStatus ?? ""
                            )
                        }
                    )
                )
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)

                Text(entry.risk.projectNames ?? entry.projectName)
                    .frame(width: Col.project, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)

                TextField(
                    "Owner",
                    text: Binding(
                        get: { entry.risk.displayOwner },
                        set: {
                            store.updateRiskQuick(
                                riskID: entry.risk.id,
                                title: entry.risk.displayTitle,
                                owner: $0,
                                severity: entry.risk.severity,
                                status: entry.risk.riskStatus ?? ""
                            )
                        }
                    )
                )
                .textFieldStyle(.plain)
                .frame(width: Col.owner)

                Picker(
                    "Sévérité",
                    selection: Binding(
                        get: { entry.risk.severity },
                        set: {
                            store.updateRiskQuick(
                                riskID: entry.risk.id,
                                title: entry.risk.displayTitle,
                                owner: entry.risk.displayOwner,
                                severity: $0,
                                status: entry.risk.riskStatus ?? ""
                            )
                        }
                    )
                ) {
                    ForEach(RiskSeverity.allCases) { severity in
                        Text(severity.label.appLocalized(language: appState.interfaceLanguage)).tag(severity)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: Col.severity)

                RiskStatusMenu(
                    status: RiskStatus.from(rawString: entry.risk.riskStatus) ?? .toDo,
                    onChange: { newStatus in
                        store.updateRiskStatus(riskID: entry.risk.id, status: newStatus)
                    }
                )
                .frame(width: Col.status, alignment: .leading)

                Text(scoreLabel(for: entry.risk.score0to10))
                    .frame(width: Col.score, alignment: .trailing)
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { toggleExpansion(entry.risk.id) }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                        .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(width: Col.expand)
            }
            .frame(height: 36)

            if isExpanded {
                RiskHistoryInlinePanel(riskID: entry.risk.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    // MARK: - Helpers

    private func toggleExpansion(_ id: UUID) {
        if expandedRiskIDs.contains(id) {
            expandedRiskIDs.remove(id)
        } else {
            expandedRiskIDs.insert(id)
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
            title: "Import des risques",
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
                let drafts = try await Task.detached(priority: .userInitiated) { () throws -> [RiskImportDraft] in
                    try RiskImportService.importRisks(from: importURL, reporter: reporter)
                }.value

                try Task.checkCancellation()

                let importResult = try await currentStore.importRisksAsync(drafts, reporter: reporter)

                if let riskID = importResult.firstImportedOrUpdatedRiskID {
                    appState.openRisk(riskID)
                }

                importFeedbackMessage = appState.localizedFormat("Import terminé : %@", importResult.summary)
            } catch is CancellationError {
                importFeedbackMessage = appState.localized("Import annulé.")
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
    }

    private func scoreLabel(for score: Double?) -> String {
        guard let score else { return "-" }
        return score.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var scopedRisks: [RiskEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.risks.filter { $0.projectID == primaryProjectID }
        }
        return store.risks
    }

    private var filteredRisks: [RiskEntry] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return scopedRisks.sorted(using: sortOrder) }
        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
        return scopedRisks.filter { entry in
            let values = [
                entry.risk.displayTitle,
                entry.risk.displayOwner,
                entry.risk.displayStatus,
                entry.risk.severity.label.appLocalized(language: appState.interfaceLanguage),
                entry.projectName,
                entry.risk.projectNames ?? "",
                entry.risk.externalID ?? ""
            ]
            let normalized = values.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            return terms.allSatisfy { term in
                normalized.contains(where: { $0.contains(term) })
            }
        }
        .sorted(using: sortOrder)
    }

    private var selectedRisksForExport: [RiskEntry] {
        filteredRisks.filter { selectedRiskIDs.contains($0.risk.id) }
    }

    private func prepareExport(risks: [RiskEntry], filenameSuffix: String) {
        guard risks.isEmpty == false else { return }
        let headers = ["ID", "Titre", "Projet", "Owner", "Severite", "Statut", "Score"]
            .map { appState.localized($0) }
        let rows = risks.map { entry in
            [
                entry.risk.externalID ?? "",
                entry.risk.displayTitle,
                entry.risk.projectNames ?? entry.projectName,
                entry.risk.displayOwner,
                entry.risk.severity.label.appLocalized(language: appState.interfaceLanguage),
                entry.risk.displayStatus,
                scoreLabel(for: entry.risk.score0to10)
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-risques-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }

    private func deleteRisk(_ riskID: UUID) {
        store.deleteRisk(riskID: riskID)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

// MARK: - Sort header

private struct RiskSortHeader: View {
    @Environment(AppState.self) private var appState

    let label: String
    let comparator: KeyPathComparator<RiskEntry>
    @Binding var sortOrder: [KeyPathComparator<RiskEntry>]

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

// MARK: - Inline history panel

private struct RiskHistoryInlinePanel: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store
    let riskID: UUID

    var body: some View {
        let entries = store.risks.first(where: { $0.risk.id == riskID })?.risk.historyEntriesChronological ?? []

        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.top, 4)

            if entries.isEmpty {
                Text(appState.localized("Aucune entrée d'historique pour ce risque."))
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
                            HStack(spacing: 4) {
                                Text(entry.kind.label.appLocalized(language: appState.interfaceLanguage))
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

// MARK: - RiskEntry sort extensions

private extension RiskEntry {
    var externalIDSortKey: String { risk.externalID ?? "" }
    var titleSortKey: String { risk.displayTitle }
    var projectsSortKey: String { risk.projectNames ?? projectName }
    var ownerSortKey: String { risk.displayOwner }
    var severitySortWeight: Int { risk.severity.sortWeight }
    var statusSortWeight: Int {
        (RiskStatus.from(rawString: risk.riskStatus) ?? .toDo).sortWeight
    }
    var scoreSortValue: Double { risk.score0to10 ?? -1 }
}

// MARK: - Status badge & menu

struct RiskStatusBadge: View {
    @Environment(AppState.self) private var appState

    let status: RiskStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 8, height: 8)
            Text(status.label.appLocalized(language: appState.interfaceLanguage))
                .font(.caption.weight(.medium))
                .foregroundStyle(status.tintColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(status.tintColor.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(status.tintColor.opacity(0.35), lineWidth: 0.5)
        )
    }
}

struct RiskStatusMenu: View {
    @Environment(AppState.self) private var appState

    let status: RiskStatus
    let onChange: (RiskStatus) -> Void

    var body: some View {
        Menu {
            ForEach(RiskStatus.allCases) { option in
                Button {
                    if option != status { onChange(option) }
                } label: {
                    HStack {
                        Circle()
                            .fill(option.tintColor)
                            .frame(width: 10, height: 10)
                        Text(option.label.appLocalized(language: appState.interfaceLanguage))
                        if option == status {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            RiskStatusBadge(status: status)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Risk editor sheet

private struct ManualRiskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let entry: RiskEntry?
    let suggestedProjectID: UUID?

    @State private var projectID: UUID?
    @State private var title: String
    @State private var mitigation: String
    @State private var owner: String
    @State private var severity: RiskSeverity
    @State private var status: RiskStatus
    @State private var dueDate: Date
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false
    @State private var newCommentText: String = ""

    init(entry: RiskEntry?, suggestedProjectID: UUID?) {
        self.entry = entry
        self.suggestedProjectID = suggestedProjectID
        _projectID = State(initialValue: entry?.projectID)
        _title = State(initialValue: entry?.risk.displayTitle ?? "")
        _mitigation = State(initialValue: entry?.risk.mitigation ?? "")
        _owner = State(initialValue: entry?.risk.displayOwner ?? "")
        _severity = State(initialValue: entry?.risk.severity ?? .medium)
        _status = State(initialValue: RiskStatus.from(rawString: entry?.risk.riskStatus) ?? .toDo)
        _dueDate = State(initialValue: entry?.risk.dueDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                if entry == nil {
                    Picker(localized("Projet"), selection: $projectID) {
                        Text(localized("Sélectionner")).tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                } else {
                    LabeledContent("Projet") {
                        Text(store.projectName(for: projectID))
                            .foregroundStyle(.secondary)
                    }
                }

                TextField(localized("Risque"), text: $title)
                TextField(localized("Mitigation"), text: $mitigation, axis: .vertical)
                    .lineLimit(3...5)
                TextField(localized("Owner"), text: $owner)

                Picker(localized("Sévérité"), selection: $severity) {
                    ForEach(RiskSeverity.allCases) { s in
                        Text(s.label.appLocalized(language: appState.interfaceLanguage)).tag(s)
                    }
                }

                Picker(localized("Statut"), selection: $status) {
                    ForEach(RiskStatus.allCases) { s in
                        HStack {
                            Circle()
                                .fill(s.tintColor)
                                .frame(width: 10, height: 10)
                            Text(s.label.appLocalized(language: appState.interfaceLanguage))
                        }
                        .tag(s)
                    }
                }

                DatePicker(localized("Date d'action cible"), selection: $dueDate, displayedComponents: .date)

                if let entry {
                    historySection(for: entry.risk.id)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(appState.localized(entry == nil ? "Nouveau risque" : "Modifier le risque"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(entry == nil ? "Créer" : "Enregistrer")) {
                        save()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 380)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
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
            if projectID == nil {
                projectID = suggestedProjectID ?? store.projects.first?.id
            }
            captureInitialSnapshotIfNeeded()
        }
    }

    @ViewBuilder
    private func historySection(for riskID: UUID) -> some View {
        let currentRisk = store.risks.first(where: { $0.risk.id == riskID })?.risk
        let entries = currentRisk?.historyEntriesChronological ?? []

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
                        store.addRiskComment(riskID: riskID, text: trimmed)
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

    private var formIsInvalid: Bool {
        (entry == nil && projectID == nil)
            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var snapshot: String {
        [
            projectID?.uuidString ?? "",
            title,
            mitigation,
            owner,
            severity.rawValue,
            status.rawValue,
            String(dueDate.timeIntervalSinceReferenceDate)
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

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMitigation = mitigation.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry {
            store.updateRisk(
                riskID: entry.risk.id,
                title: cleanedTitle,
                mitigation: cleanedMitigation,
                owner: cleanedOwner,
                severity: severity,
                dueDate: dueDate,
                status: status
            )
            appState.openRisk(entry.risk.id)
        } else {
            guard let projectID else { return }
            store.addRisk(
                to: projectID,
                title: cleanedTitle,
                mitigation: cleanedMitigation,
                owner: cleanedOwner,
                severity: severity,
                dueDate: dueDate,
                status: status
            )
            appState.selectedSection = .risks
        }
        dismiss()
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

// MARK: - Editor context

private enum RiskRegistryEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let riskID):
            "edit-\(riskID.uuidString)"
        }
    }

    @MainActor
    func entry(in store: SamouraiStore) -> RiskEntry? {
        switch self {
        case .create:
            nil
        case .edit(let riskID):
            store.risks.first(where: { $0.risk.id == riskID })
        }
    }
}
