import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MeetingWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var searchText = ""
    @State private var editorContext: MeetingEditorContext?
    @State private var meetingPendingDeletion: ProjectMeeting?
    @State private var dropFeedbackMessage: String?
    @State private var isDropTargeted = false
    @State private var selectedMeetingIDs: Set<UUID> = []
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "meetings"
    @State private var isShowingDeleteConfirmation = false
    @State private var sortOrder: [KeyPathComparator<ProjectMeeting>] = [
        .init(\.meetingAt, order: .reverse)
    ]

    var body: some View {
        @Bindable var appState = appState

        SamouraiWorkspaceSplitView(sidebarMinWidth: 860, sidebarIdealWidth: 980) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Registre des réunions")
                            .font(.title2.weight(.semibold))
                        Text("\(filteredMeetings.count) / \(scopedMeetings.count) réunion(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedMeetingIDs.isEmpty == false {
                        Button {
                            if let selectedMeetingID = selectedMeetingIDs.singleSelection {
                                editorContext = .edit(selectedMeetingID)
                            }
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .disabled(selectedMeetingIDs.count != 1)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedMeetingIDs.count > 1 ? "Supprimer (\(selectedMeetingIDs.count))" : "Supprimer",
                                systemImage: "trash"
                            )
                        }
                    }

                    Menu {
                        Button("Exporter la vue (\(filteredMeetings.count))") {
                            prepareExport(meetings: filteredMeetings, filenameSuffix: "vue")
                        }
                        .disabled(filteredMeetings.isEmpty)

                        Button("Exporter la sélection (\(selectedMeetingsForExport.count))") {
                            prepareExport(meetings: selectedMeetingsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedMeetingsForExport.isEmpty)
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        editorContext = .create(nil)
                    } label: {
                        Label("Nouvelle réunion", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Recherche (titre, transcript, résumé IA, participants, projet)", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }

                    dropZone
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if scopedMeetings.isEmpty {
                    ContentUnavailableView(
                        "Aucune réunion",
                        systemImage: "person.2.badge.gearshape",
                        description: Text("Ajoute des réunions manuellement ou en glisser-déposer depuis ton calendrier.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMeetings.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Ajuste la recherche pour retrouver une réunion.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filteredMeetings, selection: $selectedMeetingIDs, sortOrder: $sortOrder) {
                        TableColumn("Date", value: \.meetingAt) { meeting in
                            Text(meeting.meetingAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        .width(min: 165, ideal: 190)

                        TableColumn("Réunion", value: \.displayTitle) { meeting in
                            TextField(
                                "Réunion",
                                text: Binding(
                                    get: { meeting.title },
                                    set: {
                                        store.updateMeeting(
                                            meetingID: meeting.id,
                                            title: $0,
                                            projectID: meeting.projectID,
                                            meetingAt: meeting.meetingAt,
                                            durationMinutes: meeting.durationMinutes,
                                            mode: meeting.mode,
                                            organizer: meeting.organizer,
                                            participants: meeting.participants,
                                            locationOrLink: meeting.locationOrLink,
                                            notes: meeting.notes,
                                            transcript: meeting.transcript,
                                            aiSummary: meeting.aiSummary
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                            .fontWeight(.medium)
                        }
                        .width(min: 220, ideal: 320)

                        TableColumn("Projet", value: \.projectIDSortKey) { meeting in
                            Text(store.projectName(for: meeting.projectID))
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Mode", value: \.modeSortKey) { meeting in
                            Picker(
                                "Mode",
                                selection: Binding(
                                    get: { meeting.mode },
                                    set: {
                                        store.updateMeeting(
                                            meetingID: meeting.id,
                                            title: meeting.title,
                                            projectID: meeting.projectID,
                                            meetingAt: meeting.meetingAt,
                                            durationMinutes: meeting.durationMinutes,
                                            mode: $0,
                                            organizer: meeting.organizer,
                                            participants: meeting.participants,
                                            locationOrLink: meeting.locationOrLink,
                                            notes: meeting.notes,
                                            transcript: meeting.transcript,
                                            aiSummary: meeting.aiSummary
                                        )
                                    }
                                )
                            ) {
                                ForEach(MeetingMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .width(min: 120, ideal: 140)

                        TableColumn("Durée", value: \.durationMinutes) { meeting in
                            Text("\(meeting.durationMinutes) min")
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Résumé IA", value: \.aiSummary) { meeting in
                            Text(meeting.aiSummary)
                                .lineLimit(2)
                        }
                        .width(min: 260, ideal: 420)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .frame(minWidth: 860, idealWidth: 980)

        } detail: {
            Group {
                if let meeting = selectedMeeting {
                    MeetingDetailView(
                        meeting: meeting,
                        projectName: store.projectName(for: meeting.projectID),
                        onEdit: { editorContext = .edit(meeting.id) },
                        onDelete: {
                            meetingPendingDeletion = meeting
                            isShowingDeleteConfirmation = true
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Sélectionne une réunion",
                        systemImage: "sidebar.left",
                        description: Text("Chaque réunion conserve le transcript brut et le compte rendu synthétique IA.")
                    )
                }
            }
        }
        .inspector(isPresented: Binding(
            get: { editorContext != nil },
            set: { if $0 == false { editorContext = nil } }
        )) {
            if let context = editorContext {
                MeetingEditorSheet(meeting: context.meeting(in: store), prefill: context.prefill)
            }
        }
        .inspectorColumnWidth(min: 500, ideal: 680, max: 820)
        .dynamicWindowSizingForInspector(
            isPresented: editorContext != nil,
            preferredInspectorWidth: 680
        )
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert("Supprimer la réunion", isPresented: $isShowingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if selectedMeetingIDs.isEmpty == false {
                    for meetingID in selectedMeetingIDs {
                        store.deleteMeeting(meetingID: meetingID)
                    }
                    selectedMeetingIDs.removeAll()
                    appState.selectedMeetingID = nil
                } else if let pending = meetingPendingDeletion {
                    store.deleteMeeting(meetingID: pending.id)
                }
                meetingPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                selectedMeetingIDs.count > 1
                ? "Ces réunions seront retirées du registre."
                : "Cette réunion sera retirée du registre."
            )
        }
        .alert("Import glisser-déposer", isPresented: Binding(
            get: { dropFeedbackMessage != nil },
            set: { if $0 == false { dropFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dropFeedbackMessage ?? "")
        }
        .onChange(of: selectedMeetingIDs) { _, newSelection in
            appState.selectedMeetingID = newSelection.singleSelection
        }
        .onChange(of: appState.selectedMeetingID) { _, newID in
            guard let newID else { return }
            if selectedMeetingIDs != [newID] {
                selectedMeetingIDs = [newID]
            }
        }
        .onChange(of: store.meetings.map(\.id)) { _, meetingIDs in
            let existingIDs = Set(meetingIDs)
            selectedMeetingIDs = selectedMeetingIDs.intersection(existingIDs)
            appState.selectedMeetingID = selectedMeetingIDs.singleSelection
        }
    }

    private var dropZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Glisser-déposer depuis calendrier ou texte", systemImage: "square.and.arrow.down.on.square")
                .font(.headline)

            Text("Dépose un fichier .ics, .txt ou du texte brut pour préremplir une réunion avant validation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isDropTargeted ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .dropDestination(for: URL.self) { droppedURLs, _ in
            guard let firstURL = droppedURLs.first else { return false }
            do {
                let prefill = try MeetingDropParser.parseURL(firstURL)
                editorContext = .create(prefill)
                return true
            } catch {
                dropFeedbackMessage = error.localizedDescription
                return false
            }
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .dropDestination(for: String.self) { droppedStrings, _ in
            guard let firstString = droppedStrings.first else { return false }
            let prefill = MeetingDropParser.parseTextPayload(firstString)
            editorContext = .create(prefill)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
    }

    private var filteredMeetings: [ProjectMeeting] {
        let baseMeetings = scopedMeetings
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return baseMeetings.sorted(using: sortOrder) }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return baseMeetings.sorted(using: sortOrder) }

        return baseMeetings.filter { meeting in
            let searchableValues: [String] = [
                meeting.title,
                store.projectName(for: meeting.projectID),
                meeting.mode.label,
                meeting.organizer,
                meeting.participants,
                meeting.locationOrLink,
                meeting.notes,
                meeting.transcript,
                meeting.aiSummary,
                meeting.meetingAt.formatted(date: .abbreviated, time: .shortened)
            ]
            let normalizedValues = searchableValues.map(normalize)
            return terms.allSatisfy { term in
                normalizedValues.contains(where: { $0.contains(term) })
            }
        }
        .sorted(using: sortOrder)
    }

    private var scopedMeetings: [ProjectMeeting] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.meetings.filter { $0.projectID == primaryProjectID }
        }
        return store.meetings
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedMeeting: ProjectMeeting? {
        guard let selectedMeetingID = selectedMeetingIDs.singleSelection else { return nil }
        return store.meeting(with: selectedMeetingID)
    }

    private var selectedMeetingsForExport: [ProjectMeeting] {
        filteredMeetings.filter { selectedMeetingIDs.contains($0.id) }
    }

    private func prepareExport(meetings: [ProjectMeeting], filenameSuffix: String) {
        guard meetings.isEmpty == false else { return }
        let headers = ["Date", "Reunion", "Projet", "Mode", "DureeMin", "Participants", "Organisateur"]
        let rows = meetings.map { meeting in
            [
                meeting.meetingAt.formatted(date: .abbreviated, time: .shortened),
                meeting.displayTitle,
                store.projectName(for: meeting.projectID),
                meeting.mode.label,
                String(meeting.durationMinutes),
                meeting.participants,
                meeting.organizer
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-reunions-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }
}

private extension ProjectMeeting {
    var projectIDSortKey: String { projectID?.uuidString ?? "" }
    var modeSortKey: String { mode.rawValue }
}

private struct MeetingDetailView: View {
    let meeting: ProjectMeeting
    let projectName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(meeting.displayTitle)
                            .font(.largeTitle.weight(.semibold))

                        HStack(spacing: 14) {
                            Label(projectName, systemImage: "folder")
                            Label(meeting.mode.label, systemImage: meeting.mode.systemImage)
                            Label(meeting.meetingAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            Label("\(meeting.durationMinutes) min", systemImage: "timer")
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

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

                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        detailCard(title: "Organisateur", value: meeting.organizer)
                        detailCard(title: "Participants", value: meeting.participants)
                    }
                    GridRow {
                        detailCard(title: "Lieu / Lien", value: meeting.locationOrLink)
                        detailCard(title: "Notes", value: meeting.notes)
                    }
                }

                textBlock(title: "Compte Rendu Synthétique (IA)", value: meeting.aiSummary)
                textBlock(title: "Transcript Brut", value: meeting.transcript)

                HStack(spacing: 20) {
                    Label("Créée: \(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.plus")
                    Label("Modifiée: \(meeting.updatedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func textBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct MeetingEditorPrefill {
    var title: String = ""
    var meetingAt: Date = .now
    var durationMinutes: Int = 60
    var mode: MeetingMode = .virtual
    var organizer: String = ""
    var participants: String = ""
    var locationOrLink: String = ""
    var notes: String = ""
    var transcript: String = ""
    var aiSummary: String = ""
}

private struct MeetingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let meeting: ProjectMeeting?
    let prefill: MeetingEditorPrefill?

    @State private var title: String
    @State private var projectID: UUID?
    @State private var meetingAt: Date
    @State private var durationMinutesText: String
    @State private var mode: MeetingMode
    @State private var organizer: String
    @State private var participants: String
    @State private var locationOrLink: String
    @State private var notes: String
    @State private var transcript: String
    @State private var aiSummary: String
    @State private var validationMessage: String?
    @State private var didApplyPrimaryProjectDefault = false

    init(meeting: ProjectMeeting?, prefill: MeetingEditorPrefill?) {
        self.meeting = meeting
        self.prefill = prefill

        let effectiveTitle = meeting?.title ?? prefill?.title ?? ""
        let effectiveAt = meeting?.meetingAt ?? prefill?.meetingAt ?? .now
        let effectiveDuration = meeting?.durationMinutes ?? prefill?.durationMinutes ?? 60
        let effectiveMode = meeting?.mode ?? prefill?.mode ?? .virtual

        _title = State(initialValue: effectiveTitle)
        _projectID = State(initialValue: meeting?.projectID)
        _meetingAt = State(initialValue: effectiveAt)
        _durationMinutesText = State(initialValue: "\(effectiveDuration)")
        _mode = State(initialValue: effectiveMode)
        _organizer = State(initialValue: meeting?.organizer ?? prefill?.organizer ?? "")
        _participants = State(initialValue: meeting?.participants ?? prefill?.participants ?? "")
        _locationOrLink = State(initialValue: meeting?.locationOrLink ?? prefill?.locationOrLink ?? "")
        _notes = State(initialValue: meeting?.notes ?? prefill?.notes ?? "")
        _transcript = State(initialValue: meeting?.transcript ?? prefill?.transcript ?? "")
        _aiSummary = State(initialValue: meeting?.aiSummary ?? prefill?.aiSummary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations réunion") {
                    TextField("Titre", text: $title)

                    Picker("Projet", selection: $projectID) {
                        Text("Sans projet")
                            .tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }

                    DatePicker("Date et heure", selection: $meetingAt)

                    TextField("Durée (minutes)", text: $durationMinutesText)

                    Picker("Type", selection: $mode) {
                        ForEach(MeetingMode.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }

                    TextField("Organisateur", text: $organizer)
                    TextField("Participants", text: $participants)
                    TextField("Lieu ou lien visio", text: $locationOrLink)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Compte Rendu Synthétique (IA) *") {
                    TextEditor(text: $aiSummary)
                        .frame(minHeight: 140)
                }

                Section("Transcript Brut *") {
                    TextEditor(text: $transcript)
                        .frame(minHeight: 180)
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
            .navigationTitle(meeting == nil ? "Nouvelle réunion" : "Modifier la réunion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(meeting == nil ? "Créer" : "Enregistrer") {
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
        .frame(minWidth: 760, minHeight: 760)
        .onAppear {
            applyPrimaryProjectDefaultIfNeeded()
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAISummary = aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedTitle.isEmpty == false else {
            validationMessage = "Le titre de réunion est obligatoire."
            return
        }

        guard cleanedAISummary.isEmpty == false else {
            validationMessage = "Le Compte Rendu Synthétique (IA) est obligatoire."
            return
        }

        guard cleanedTranscript.isEmpty == false else {
            validationMessage = "Le Transcript Brut est obligatoire."
            return
        }

        guard let durationMinutes = Int(durationMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)), durationMinutes > 0 else {
            validationMessage = "La durée doit être un nombre positif en minutes."
            return
        }

        if let meeting {
            store.updateMeeting(
                meetingID: meeting.id,
                title: cleanedTitle,
                projectID: projectID,
                meetingAt: meetingAt,
                durationMinutes: durationMinutes,
                mode: mode,
                organizer: organizer,
                participants: participants,
                locationOrLink: locationOrLink,
                notes: notes,
                transcript: cleanedTranscript,
                aiSummary: cleanedAISummary
            )
            appState.openMeeting(meeting.id)
        } else {
            let createdMeetingID = store.addMeeting(
                title: cleanedTitle,
                projectID: projectID,
                meetingAt: meetingAt,
                durationMinutes: durationMinutes,
                mode: mode,
                organizer: organizer,
                participants: participants,
                locationOrLink: locationOrLink,
                notes: notes,
                transcript: cleanedTranscript,
                aiSummary: cleanedAISummary
            )
            appState.openMeeting(createdMeetingID)
        }

        dismiss()
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard meeting == nil, projectID == nil else { return }
        projectID = appState.resolvedPrimaryProjectID(in: store)
    }
}

private enum MeetingEditorContext: Identifiable {
    case create(MeetingEditorPrefill?)
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let meetingID):
            "edit-\(meetingID.uuidString)"
        }
    }

    @MainActor
    func meeting(in store: SamouraiStore) -> ProjectMeeting? {
        switch self {
        case .create:
            nil
        case .edit(let meetingID):
            store.meeting(with: meetingID)
        }
    }

    var prefill: MeetingEditorPrefill? {
        switch self {
        case .create(let prefill):
            prefill
        case .edit:
            nil
        }
    }
}

private enum MeetingDropParser {
    static func parseURL(_ url: URL) throws -> MeetingEditorPrefill {
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        let data = try Data(contentsOf: url)

        if ext == "ics" {
            guard let text = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "MeetingDrop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Le fichier ICS est illisible."])
            }
            return parseICS(text)
        }

        if let text = String(data: data, encoding: .utf8) {
            return parseTextPayload(text, suggestedTitle: url.deletingPathExtension().lastPathComponent)
        }

        throw NSError(domain: "MeetingDrop", code: 2, userInfo: [NSLocalizedDescriptionKey: "Format non pris en charge. Utilise .ics, .txt, .md ou texte brut."])
    }

    static func parseTextPayload(_ text: String, suggestedTitle: String? = nil) -> MeetingEditorPrefill {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = cleaned.split(separator: "\n").map(String.init)
        let titleCandidate = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        var prefill = MeetingEditorPrefill()
        prefill.title = (titleCandidate?.isEmpty == false ? titleCandidate! : (firstLine?.isEmpty == false ? firstLine! : "Réunion importée"))
        prefill.notes = cleaned
        prefill.transcript = cleaned
        prefill.aiSummary = "Résumé IA à compléter"
        prefill.mode = inferMode(from: cleaned)
        return prefill
    }

    private static func parseICS(_ content: String) -> MeetingEditorPrefill {
        let lines = unfoldICSLines(content)

        let summary = value(for: "SUMMARY", in: lines) ?? "Réunion importée"
        let description = value(for: "DESCRIPTION", in: lines) ?? ""
        let organizerRaw = value(for: "ORGANIZER", in: lines) ?? ""
        let organizer = organizerRaw.replacingOccurrences(of: "mailto:", with: "", options: .caseInsensitive)
        let location = value(for: "LOCATION", in: lines) ?? ""
        let dtStartRaw = value(for: "DTSTART", in: lines)
        let dtEndRaw = value(for: "DTEND", in: lines)

        let meetingAt = parseICSDate(dtStartRaw) ?? .now
        let endAt = parseICSDate(dtEndRaw)
        let durationMinutes: Int
        if let endAt, endAt > meetingAt {
            durationMinutes = max(Int(endAt.timeIntervalSince(meetingAt) / 60.0), 1)
        } else {
            durationMinutes = 60
        }

        var prefill = MeetingEditorPrefill()
        prefill.title = summary
        prefill.meetingAt = meetingAt
        prefill.durationMinutes = durationMinutes
        prefill.mode = inferMode(from: "\(location) \(description)")
        prefill.organizer = organizer
        prefill.locationOrLink = location
        prefill.notes = description
        prefill.transcript = description
        prefill.aiSummary = "Résumé IA à compléter"
        return prefill
    }

    private static func unfoldICSLines(_ content: String) -> [String] {
        var unfolded: [String] = []
        for rawLine in content.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if let lastIndex = unfolded.indices.last {
                    unfolded[lastIndex] += line.trimmingCharacters(in: .whitespaces)
                }
            } else {
                unfolded.append(line)
            }
        }
        return unfolded
    }

    private static func value(for key: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.uppercased().hasPrefix("\(key):") || $0.uppercased().hasPrefix("\(key);") }) else {
            return nil
        }

        guard let separatorIndex = line.firstIndex(of: ":") else { return nil }
        let rawValue = String(line[line.index(after: separatorIndex)...])
        return rawValue
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseICSDate(_ rawValue: String?) -> Date? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }

        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd'T'HHmm",
            "yyyyMMdd"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if format.hasSuffix("'Z'") {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            } else {
                formatter.timeZone = .current
            }

            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    private static func inferMode(from text: String) -> MeetingMode {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("http") || normalized.contains("teams") || normalized.contains("zoom") || normalized.contains("meet") {
            return .virtual
        }
        return .physical
    }
}
