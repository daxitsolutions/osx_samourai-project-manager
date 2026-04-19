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

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Registre des décisions")
                            .font(.title2.weight(.semibold))
                        Text("\(filteredDecisions.count) / \(scopedDecisions.count) décision(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedDecision != nil {
                        Button {
                            if let selectedDecisionID = appState.selectedDecisionID {
                                editorContext = .edit(selectedDecisionID)
                            }
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            decisionPendingDeletion = selectedDecision
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
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
                    Table(filteredDecisions, selection: $appState.selectedDecisionID) {
                        TableColumn("Ref") { decision in
                            Text("D-\(decision.sequenceNumber)")
                                .monospacedDigit()
                        }
                        .width(min: 70, ideal: 80)

                        TableColumn("Statut") { decision in
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

                        TableColumn("Décision") { decision in
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

                        TableColumn("Projet") { decision in
                            Text(store.projectName(for: decision.projectID))
                        }
                        .width(min: 150, ideal: 220)

                        TableColumn("Réunions liées") { decision in
                            Text("\(decision.meetingIDs.count)")
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Événements liés") { decision in
                            Text("\(decision.eventIDs.count)")
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("Révisions") { decision in
                            Text("\(decision.history.count)")
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Commentaires") { decision in
                            Text("\(decision.comments.count)")
                        }
                        .width(min: 110, ideal: 130)
                    }
                }
            }
            .frame(minWidth: 900, idealWidth: 1050)

            Group {
                if let decision = selectedDecision {
                    DecisionDetailView(
                        decision: decision,
                        projectName: store.projectName(for: decision.projectID),
                        meetingTitles: decision.meetingIDs.compactMap { store.meeting(with: $0)?.displayTitle },
                        eventTitles: decision.eventIDs.compactMap { store.event(with: $0)?.displayTitle },
                        impactedResourceNames: decision.impactedResourceIDs.compactMap { store.resource(with: $0)?.displayName },
                        commentAuthor: $newCommentAuthor,
                        commentBody: $newCommentBody,
                        onEdit: { editorContext = .edit(decision.id) },
                        onDelete: { decisionPendingDeletion = decision },
                        onAddComment: {
                            addComment(to: decision.id)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Sélectionne une décision",
                        systemImage: "sidebar.left",
                        description: Text("La vue détail conserve la chaîne complète de révisions et commentaires chronologiques.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $editorContext) { context in
            DecisionEditorSheet(decision: context.decision(in: store))
        }
        .alert("Supprimer la décision", isPresented: Binding(
            get: { decisionPendingDeletion != nil },
            set: { if $0 == false { decisionPendingDeletion = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let pending = decisionPendingDeletion {
                    if appState.selectedDecisionID == pending.id {
                        appState.selectedDecisionID = nil
                    }
                    store.deleteDecision(decisionID: pending.id)
                }
                decisionPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                decisionPendingDeletion = nil
            }
        } message: {
            Text("La décision sera retirée du registre de gouvernance.")
        }
        .alert("Commentaire", isPresented: Binding(
            get: { commentValidationMessage != nil },
            set: { if $0 == false { commentValidationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(commentValidationMessage ?? "")
        }
        .onChange(of: store.decisions.map(\.id)) { _, decisionIDs in
            let existingIDs = Set(decisionIDs)
            if let selectedDecisionID = appState.selectedDecisionID, existingIDs.contains(selectedDecisionID) == false {
                appState.selectedDecisionID = nil
            }
        }
    }

    private var filteredDecisions: [ProjectDecision] {
        let baseDecisions = scopedDecisions
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return baseDecisions }

        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(normalize)
            .filter { $0.isEmpty == false }

        guard terms.isEmpty == false else { return baseDecisions }

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
        guard let selectedDecisionID = appState.selectedDecisionID else { return nil }
        return store.decision(with: selectedDecisionID)
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

private struct DecisionDetailView: View {
    let decision: ProjectDecision
    let projectName: String
    let meetingTitles: [String]
    let eventTitles: [String]
    let impactedResourceNames: [String]
    @Binding var commentAuthor: String
    @Binding var commentBody: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddComment: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("D-\(decision.sequenceNumber) · \(decision.displayTitle)")
                            .font(.largeTitle.weight(.semibold))

                        HStack(spacing: 14) {
                            Label(decision.status.label, systemImage: "flag.fill")
                                .foregroundStyle(Color(decision.status.tintName))
                            Label(projectName, systemImage: "folder")
                            Label("\(decision.history.count) révision(s)", systemImage: "clock.arrow.circlepath")
                            Label("\(decision.comments.count) commentaire(s)", systemImage: "bubble.left.and.bubble.right")
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

                textBlock(title: "Décision", value: decision.details)

                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        detailCard(title: "Réunions liées", value: meetingTitles.isEmpty ? "Aucune" : meetingTitles.joined(separator: "\n"))
                        detailCard(title: "Événements liés", value: eventTitles.isEmpty ? "Aucun" : eventTitles.joined(separator: "\n"))
                    }
                    GridRow {
                        detailCard(title: "Ressources impactées", value: impactedResourceNames.isEmpty ? "Aucune" : impactedResourceNames.joined(separator: "\n"))
                        detailCard(title: "Métadonnées", value: "Créée: \(decision.createdAt.formatted(date: .abbreviated, time: .shortened))\nModifiée: \(decision.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                }

                timelineSection
                commentsSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historique des itérations")
                .font(.title3.weight(.semibold))

            if decision.history.isEmpty {
                Text("Aucune révision")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(decision.history.sorted(by: { $0.recordedAt < $1.recordedAt })) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(decision.status.tintName))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rev. \(entry.revision) · \(entry.status.shortLabel)")
                                .font(.headline)
                            Text(entry.summary)
                            Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commentaires chronologiques")
                .font(.title3.weight(.semibold))

            if decision.comments.isEmpty {
                Text("Aucun commentaire")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(decision.comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comment.author) · \(comment.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(comment.body)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Auteur (optionnel)", text: $commentAuthor)
                TextField("Ajouter un commentaire", text: $commentBody, axis: .vertical)
                    .lineLimit(2...4)

                Button {
                    onAddComment()
                } label: {
                    Label("Ajouter commentaire", systemImage: "plus.bubble")
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
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
                        dismiss()
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
        .onAppear {
            applyPrimaryProjectDefaultIfNeeded()
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
