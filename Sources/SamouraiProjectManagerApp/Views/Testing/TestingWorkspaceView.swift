import SwiftUI
import UniformTypeIdentifiers

struct TestingWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var selectedStatus: ProjectTestingPhaseStatus?
    @State private var selectedPhaseKind: ProjectTestingPhaseKind?
    @State private var selectedRows: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<TestingRow>] = [
        .init(\TestingRow.projectName, order: .reverse)
    ]
    @State private var isShowingAddSheet = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "testing"

    var body: some View {
        SamouraiWorkspaceSplitView(sidebarMinWidth: 760, sidebarIdealWidth: 900, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("Testing"))
                            .font(.title2.weight(.semibold))
                        Text(appState.localizedFormat("%d / %d phase(s) de test", filteredRows.count, scopedRows.count))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button(appState.localizedFormat("Exporter la vue (%d)", filteredRows.count)) {
                            prepareExport(rows: filteredRows, filenameSuffix: "vue")
                        }
                        .disabled(filteredRows.isEmpty)

                        Button(appState.localizedFormat("Exporter la sélection (%d)", selectedRowsForExport.count)) {
                            prepareExport(rows: selectedRowsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedRowsForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label(
                            selectedRows.count > 1
                                ? appState.localizedFormat("Supprimer (%d)", selectedRows.count)
                                : appState.localized("Supprimer"),
                            systemImage: "trash"
                        )
                    }
                    .disabled(selectedRows.isEmpty)

                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label(localized("Ajouter"), systemImage: "plus")
                    }
                    .disabled(store.projects.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche (projet, owner, notes, statut)"), text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker(localized("Phase"), selection: $selectedPhaseKind) {
                        Text(localized("Toutes les phases")).tag(Optional<ProjectTestingPhaseKind>.none)
                        ForEach(ProjectTestingPhaseKind.allCases) { kind in
                            Text(kind.shortLabel).tag(Optional(kind))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)

                    Picker(localized("Statut"), selection: $selectedStatus) {
                        Text(localized("Tous les statuts")).tag(Optional<ProjectTestingPhaseStatus>.none)
                        ForEach(ProjectTestingPhaseStatus.allCases) { status in
                            Text(status.label.appLocalized(language: appState.interfaceLanguage)).tag(Optional(status))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190)

                    if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store),
                       let project = store.project(with: primaryProjectID) {
                        Text(appState.localizedFormat("Portée: %@", project.name))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(localized("Portée: Tous les projets"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedRows.isEmpty {
                    ContentUnavailableView(
                        "Aucun projet",
                        systemImage: "testtube.2",
                        description: Text(localized("Crée un projet pour piloter les phases UT, ST, IST et UAT."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredRows.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(localized("Ajuste la recherche ou les filtres pour retrouver une phase de test."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredRows, selection: $selectedRows, sortOrder: $sortOrder) {
                        TableColumnForEach(activeTableColumns) { column in
                            switch column {
                            case .project:
                                TableColumn(appState.localized(column.label), value: \TestingRow.projectName) { row in
                                    Text(row.projectName)
                                }
                                .width(min: 170, ideal: 230)

                            case .phase:
                                TableColumn(appState.localized(column.label), value: \.phaseOrder) { row in
                                    Text(row.phase.kind.shortLabel)
                                        .font(.callout.weight(.semibold))
                                }
                                .width(min: 70, ideal: 90)

                            case .status:
                                TableColumn(appState.localized(column.label), value: \.statusSortKey) { row in
                                    Picker(
                                        "Statut",
                                        selection: Binding(
                                            get: { row.phase.status },
                                            set: { newStatus in
                                                var updated = row.phase
                                                updated.status = newStatus
                                                store.replaceProjectTestingPhase(projectID: row.projectID, phase: updated)
                                            }
                                        )
                                    ) {
                                        ForEach(ProjectTestingPhaseStatus.allCases) { status in
                                            Text(status.label.appLocalized(language: appState.interfaceLanguage)).tag(status)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                                .width(min: 150, ideal: 180)

                            case .progress:
                                TableColumn(appState.localized(column.label), value: \.progressPercentSortKey) { row in
                                    TextField(
                                        "%",
                                        value: Binding(
                                            get: { row.phase.progressPercent },
                                            set: { newPercent in
                                                var updated = row.phase
                                                updated.progressPercent = min(max(newPercent, 0), 100)
                                                store.replaceProjectTestingPhase(projectID: row.projectID, phase: updated)
                                            }
                                        ),
                                        format: .number
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 62)
                                }
                                .width(min: 90, ideal: 100)

                            case .owner:
                                TableColumn(appState.localized(column.label), value: \.ownerSortKey) { row in
                                    TextField(
                                        "Owner",
                                        text: Binding(
                                            get: { row.phase.owner },
                                            set: { newOwner in
                                                var updated = row.phase
                                                updated.owner = newOwner
                                                store.replaceProjectTestingPhase(projectID: row.projectID, phase: updated)
                                            }
                                        )
                                    )
                                    .textFieldStyle(.plain)
                                }
                                .width(min: 150, ideal: 220)

                            case .blocked:
                                TableColumn(appState.localized(column.label), value: \.blockedSortKey) { row in
                                    Image(systemName: row.phase.isBlocked ? "exclamationmark.triangle.fill" : "checkmark.circle")
                                        .foregroundStyle(row.phase.isBlocked ? Color.red : .secondary)
                                }
                                .width(70)
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
        .sheet(isPresented: $isShowingAddSheet) {
            TestingPhaseEditorSheet(
                projects: store.projects,
                initialProjectID: appState.resolvedPrimaryProjectID(in: store)
            ) { payload in
                var phase = ProjectTestingPhase(kind: payload.kind)
                phase.status = payload.status
                phase.progressPercent = payload.progressPercent
                phase.owner = payload.owner
                phase.notes = payload.notes
                phase.externalURL = payload.externalURL
                phase.estimatedEndDate = payload.estimatedEndDate
                phase.actualEndDate = payload.actualEndDate
                store.replaceProjectTestingPhase(projectID: payload.projectID, phase: phase)
            }
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert(localized("Supprimer les entrées de testing"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
                for rowID in selectedRows {
                    guard let row = rowLookup[rowID] else { continue }
                    var reset = ProjectTestingPhase(kind: row.phase.kind)
                    reset.status = .notStarted
                    reset.progressPercent = 0
                    store.replaceProjectTestingPhase(projectID: row.projectID, phase: reset)
                }
                selectedRows.removeAll()
            }
            Button(localized("Annuler"), role: .cancel) {}
        } message: {
            Text(appState.localized(selectedRows.count > 1 ? "Les entrées sélectionnées seront réinitialisées." : "Cette entrée sera réinitialisée."))
        }
        .onChange(of: scopedRows.map(\.id)) { _, ids in
            let existing = Set(ids)
            selectedRows = selectedRows.intersection(existing)
        }
    }

    private var selectedRowsForExport: [TestingRow] {
        filteredRows.filter { selectedRows.contains($0.id) }
    }

    private var activeTableColumns: [TestingTableColumn] {
        appState
            .orderedVisibleTableColumnIDs(for: .testing)
            .compactMap(TestingTableColumn.init(rawValue:))
    }

    private var scopedRows: [TestingRow] {
        let projects: [Project]
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            projects = store.projects.filter { $0.id == primaryProjectID }
        } else {
            projects = store.projects
        }

        return projects.flatMap { project in
            project.orderedTestingPhases.map { phase in
                TestingRow(projectID: project.id, projectName: project.name, phase: phase)
            }
        }
    }

    private var filteredRows: [TestingRow] {
        let normalizedQuery = searchText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return scopedRows
            .filter { row in
                guard let selectedPhaseKind else { return true }
                return row.phase.kind == selectedPhaseKind
            }
            .filter { row in
                guard let selectedStatus else { return true }
                return row.phase.status == selectedStatus
            }
            .filter { row in
                guard normalizedQuery.isEmpty == false else { return true }
                let values = [
                    row.projectName,
                    row.phase.kind.label.appLocalized(language: appState.interfaceLanguage),
                    row.phase.status.label.appLocalized(language: appState.interfaceLanguage),
                    row.phase.owner,
                    row.phase.notes,
                    row.phase.externalURL
                ]
                return values.contains {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .contains(normalizedQuery)
                }
            }
            .sorted(using: sortOrder)
    }

    private var rowLookup: [String: TestingRow] {
        Dictionary(uniqueKeysWithValues: scopedRows.map { ($0.id, $0) })
    }

    private var selectedRow: TestingRow? {
        guard selectedRows.count == 1, let selectedID = selectedRows.first else { return nil }
        return rowLookup[selectedID]
    }

    private func prepareExport(rows: [TestingRow], filenameSuffix: String) {
        let headers = ["project", "phase", "status", "progress_percent", "owner", "estimated_end", "actual_end", "notes", "external_url"]
        let tableRows = rows.map { row in
            [
                row.projectName,
                row.phase.kind.shortLabel,
                row.phase.status.label.appLocalized(language: appState.interfaceLanguage),
                String(row.phase.progressPercent),
                row.phase.owner,
                row.phase.estimatedEndDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                row.phase.actualEndDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                row.phase.notes,
                row.phase.externalURL
            ]
        }

        exportDocument = EntityCSVDocument(text: EntityCSVBuilder.build(headers: headers, rows: tableRows))
        exportFilename = "testing-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct TestingRow: Identifiable, Hashable {
    let projectID: UUID
    let projectName: String
    let phase: ProjectTestingPhase

    var id: String {
        "\(projectID.uuidString)-\(phase.kind.rawValue)"
    }

    var phaseOrder: Int {
        ProjectTestingPhaseKind.allCases.firstIndex(of: phase.kind) ?? 0
    }

    var statusSortKey: String {
        phase.status.rawValue
    }

    var progressPercentSortKey: Int {
        phase.progressPercent
    }

    var ownerSortKey: String {
        phase.owner
    }

    var blockedSortKey: Int {
        phase.isBlocked ? 1 : 0
    }
}

private enum TestingTableColumn: String, CaseIterable, Identifiable, Hashable {
    case project
    case phase
    case status
    case progress
    case owner
    case blocked

    var id: String { rawValue }

    var label: String {
        AppTableID.testing.columnTitle(for: rawValue)
    }
}

private struct TestingRowDetailView: View {
    @Environment(AppState.self) private var appState

    let row: TestingRow
    let onUpdate: (ProjectTestingPhase) -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(appState.localized("Détail Testing"))
                    .font(.title2.weight(.semibold))

                HStack(spacing: 16) {
                    detailMetric(title: "Projet", value: row.projectName)
                    detailMetric(title: "Phase", value: row.phase.kind.label.appLocalized(language: appState.interfaceLanguage))
                    detailMetric(title: "RAG", value: row.phase.status.label.appLocalized(language: appState.interfaceLanguage))
                }

                Picker(
                    "Statut",
                    selection: Binding(
                        get: { row.phase.status },
                        set: {
                            var updated = row.phase
                            updated.status = $0
                            onUpdate(updated)
                        }
                    )
                ) {
                    ForEach(ProjectTestingPhaseStatus.allCases) { status in
                        Text(status.label.appLocalized(language: appState.interfaceLanguage)).tag(status)
                    }
                }

                HStack(spacing: 12) {
                    Text(localized("Progression"))
                    Slider(
                        value: Binding(
                            get: { Double(row.phase.progressPercent) },
                            set: {
                                var updated = row.phase
                                updated.progressPercent = Int($0.rounded())
                                onUpdate(updated)
                            }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    Text("\(row.phase.progressPercent)%")
                        .monospacedDigit()
                        .frame(width: 46, alignment: .trailing)
                }

                TextField(
                    "Owner",
                    text: Binding(
                        get: { row.phase.owner },
                        set: {
                            var updated = row.phase
                            updated.owner = $0
                            onUpdate(updated)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "URL externe",
                    text: Binding(
                        get: { row.phase.externalURL },
                        set: {
                            var updated = row.phase
                            updated.externalURL = $0
                            onUpdate(updated)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "Notes / blocages",
                    text: Binding(
                        get: { row.phase.notes },
                        set: {
                            var updated = row.phase
                            updated.notes = $0
                            onUpdate(updated)
                        }
                    ),
                    axis: .vertical
                )
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(localized("Supprimer"), systemImage: "trash")
                    }

                    Spacer()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.localized(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct TestingPhaseEditorSheet: View {
    struct Payload {
        let projectID: UUID
        let kind: ProjectTestingPhaseKind
        let status: ProjectTestingPhaseStatus
        let progressPercent: Int
        let owner: String
        let notes: String
        let externalURL: String
        let estimatedEndDate: Date?
        let actualEndDate: Date?
    }

    let projects: [Project]
    let initialProjectID: UUID?
    let onSave: (Payload) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedProjectID: UUID?
    @State private var selectedKind: ProjectTestingPhaseKind = .ut
    @State private var selectedStatus: ProjectTestingPhaseStatus = .notStarted
    @State private var progressPercent = 0
    @State private var owner = ""
    @State private var notes = ""
    @State private var externalURL = ""
    @State private var estimatedEndDate: Date?
    @State private var actualEndDate: Date?
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Picker(localized("Projet"), selection: $selectedProjectID) {
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                Picker(localized("Phase"), selection: $selectedKind) {
                    ForEach(ProjectTestingPhaseKind.allCases) { kind in
                        Text(kind.label.appLocalized(language: appState.interfaceLanguage)).tag(kind)
                    }
                }

                Picker(localized("Statut"), selection: $selectedStatus) {
                    ForEach(ProjectTestingPhaseStatus.allCases) { status in
                        Text(status.label.appLocalized(language: appState.interfaceLanguage)).tag(status)
                    }
                }

                Stepper(appState.localizedFormat("Progression: %d%%", progressPercent), value: $progressPercent, in: 0...100)

                TextField(localized("Owner"), text: $owner)
                TextField(localized("Notes"), text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                TextField(localized("URL externe"), text: $externalURL)

                optionalDatePicker(title: "Fin estimée", value: $estimatedEndDate)
                optionalDatePicker(title: "Fin réelle", value: $actualEndDate)
            }
            .formStyle(.grouped)
            .navigationTitle(appState.localized("Nouvelle entrée Testing"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) { requestDismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Ajouter")) {
                        guard let projectID = selectedProjectID else { return }
                        onSave(
                            Payload(
                                projectID: projectID,
                                kind: selectedKind,
                                status: selectedStatus,
                                progressPercent: progressPercent,
                                owner: owner,
                                notes: notes,
                                externalURL: externalURL,
                                estimatedEndDate: estimatedEndDate,
                                actualEndDate: actualEndDate
                            )
                        )
                        dismiss()
                    }
                    .disabled(selectedProjectID == nil)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 520)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if selectedProjectID != nil {
                Button(localized("Enregistrer")) {
                    submit()
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
            if selectedProjectID == nil {
                selectedProjectID = initialProjectID ?? projects.first?.id
            }
            captureInitialSnapshotIfNeeded()
        }
    }

    private var snapshot: String {
        [
            selectedProjectID?.uuidString ?? "",
            selectedKind.rawValue,
            selectedStatus.rawValue,
            String(progressPercent),
            owner,
            notes,
            externalURL,
            estimatedEndDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            actualEndDate.map { String($0.timeIntervalSinceReferenceDate) } ?? ""
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
        guard let projectID = selectedProjectID else { return }
        onSave(
            Payload(
                projectID: projectID,
                kind: selectedKind,
                status: selectedStatus,
                progressPercent: progressPercent,
                owner: owner,
                notes: notes,
                externalURL: externalURL,
                estimatedEndDate: estimatedEndDate,
                actualEndDate: actualEndDate
            )
        )
        dismiss()
    }

    @ViewBuilder
    private func optionalDatePicker(title: String, value: Binding<Date?>) -> some View {
        Toggle(isOn: Binding(
            get: { value.wrappedValue != nil },
            set: { isEnabled in
                value.wrappedValue = isEnabled ? (value.wrappedValue ?? .now) : nil
            }
        )) {
            Text(appState.localized(title))
        }

        if value.wrappedValue != nil {
            DatePicker(
                appState.localized(title),
                selection: Binding(
                    get: { value.wrappedValue ?? .now },
                    set: { value.wrappedValue = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
