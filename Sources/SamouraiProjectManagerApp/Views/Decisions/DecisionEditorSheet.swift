import SwiftUI

struct DecisionEditorSheet: View {
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
    @State private var meetingSearchText: String = ""
    @State private var resourceSearchText: String = ""
    @State private var titleTouched = false
    @State private var detailsTouched = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    formSection(title: localized("Décision")) {
                        VStack(alignment: .leading, spacing: 24) {
                            fieldStack(label: localized("Titre"), required: true) {
                                TextField(localized("Résumez la décision en quelques mots…"), text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minHeight: 44)
                                    .overlay(alignment: .trailing) {
                                        if titleTouched && titleIsEmpty {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .padding(.trailing, 6)
                                        }
                                    }
                                    .onChange(of: title) { _, _ in
                                        if !titleIsEmpty { titleTouched = true }
                                    }
                                if titleTouched && titleIsEmpty {
                                    Label(localized("Ce champ est obligatoire"), systemImage: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            fieldStack(label: localized("Statut")) {
                                Picker("", selection: $status) {
                                    ForEach(DecisionStatus.allCases) { value in
                                        Text(value.label.appLocalized(language: appState.interfaceLanguage)).tag(value)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            fieldStack(label: localized("Projet")) {
                                Picker("", selection: $projectID) {
                                    Text(localized("Sans projet")).tag(Optional<UUID>.none)
                                    ForEach(store.projects) { project in
                                        Text(project.name).tag(Optional(project.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(appState.resolvedPrimaryProjectID(in: store) == nil
                                     ? localized("Aucun Projet Principal défini: sélection projet manuelle.")
                                     : localized("Projet principal propagé automatiquement, modifiable si nécessaire."))
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                            }

                            fieldStack(label: localized("Description détaillée"), required: true) {
                                TextField(
                                    localized("Expliquez le contexte et les raisons de cette décision..."),
                                    text: $details,
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(4...8)
                                .onChange(of: details) { _, _ in
                                    if !detailsIsEmpty { detailsTouched = true }
                                }
                                if detailsTouched && detailsIsEmpty {
                                    Label(localized("Ce champ est obligatoire"), systemImage: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    formSection(title: localized("Liens contextuels")) {
                        VStack(alignment: .leading, spacing: 24) {
                            meetingPickerSection()
                            eventToggleSection()
                            resourcePickerSection()
                        }
                    }

                    if decision != nil {
                        formSection(title: localized("Journal de modification")) {
                            fieldStack(label: localized("Résumé du changement (optionnel)")) {
                                TextField(localized("Décrivez ce qui change dans cette révision…"), text: $changeSummary)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(.background)
            .navigationTitle(appState.localized(decision == nil ? "Nouvelle décision" : "Modifier la décision"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(decision == nil ? "Créer" : "Enregistrer")) {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
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
        .frame(minWidth: 760, minHeight: 780)
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

    private var titleIsEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var detailsIsEmpty: Bool {
        details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool { !titleIsEmpty && !detailsIsEmpty }

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

    private var visibleMeetings: [ProjectMeeting] {
        let q = meetingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [ProjectMeeting]
        if q.isEmpty {
            base = Array(store.meetings.sorted { $0.meetingAt > $1.meetingAt }.prefix(3))
        } else {
            base = store.meetings.filter {
                $0.displayTitle.lowercased().contains(q) || $0.organizer.lowercased().contains(q)
            }
        }
        let baseIDs = Set(base.map(\.id))
        let extra = store.meetings.filter { selectedMeetingIDs.contains($0.id) && !baseIDs.contains($0.id) }
        return base + extra
    }

    private var visibleResources: [Resource] {
        let q = resourceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [Resource]
        if q.isEmpty {
            base = []
        } else {
            base = Array(store.resources.filter {
                $0.displayName.lowercased().contains(q) || $0.displayPrimaryRole.lowercased().contains(q)
            }.prefix(3))
        }
        let baseIDs = Set(base.map(\.id))
        let extra = store.resources.filter { selectedResourceIDs.contains($0.id) && !baseIDs.contains($0.id) }
        return base + extra
    }

    @ViewBuilder
    private func meetingPickerSection() -> some View {
        fieldStack(label: localized("Réunions liées")) {
            if store.meetings.isEmpty {
                Text(localized("Aucune réunion disponible"))
                    .foregroundStyle(.primary.opacity(0.7))
            } else {
                TextField(localized("Rechercher une réunion…"), text: $meetingSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleMeetings) { meeting in
                        Toggle(
                            "\(meeting.displayTitle) · \(meeting.meetingAt.formatted(date: .abbreviated, time: .shortened))",
                            isOn: Binding(
                                get: { selectedMeetingIDs.contains(meeting.id) },
                                set: { isOn in
                                    if isOn { selectedMeetingIDs.insert(meeting.id) }
                                    else { selectedMeetingIDs.remove(meeting.id) }
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventToggleSection() -> some View {
        fieldStack(label: localized("Événements liés")) {
            if store.events.isEmpty {
                Text(localized("Aucun élément disponible"))
                    .foregroundStyle(.primary.opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.events) { event in
                        Toggle(
                            "\(event.displayTitle) · \(event.happenedAt.formatted(date: .abbreviated, time: .shortened))",
                            isOn: Binding(
                                get: { selectedEventIDs.contains(event.id) },
                                set: { isOn in
                                    if isOn { selectedEventIDs.insert(event.id) }
                                    else { selectedEventIDs.remove(event.id) }
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resourcePickerSection() -> some View {
        fieldStack(label: localized("Ressources impactées")) {
            TextField(localized("Rechercher une ressource…"), text: $resourceSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)

            if visibleResources.isEmpty {
                Text(localized(resourceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Saisissez un nom ou un rôle pour rechercher"
                    : "Aucun résultat"))
                    .foregroundStyle(.primary.opacity(0.7))
                    .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleResources) { resource in
                        Toggle(
                            "\(resource.displayName) · \(resource.displayPrimaryRole)",
                            isOn: Binding(
                                get: { selectedResourceIDs.contains(resource.id) },
                                set: { isOn in
                                    if isOn { selectedResourceIDs.insert(resource.id) }
                                    else { selectedResourceIDs.remove(resource.id) }
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedTitle.isEmpty == false else {
            titleTouched = true
            validationMessage = "Le titre est obligatoire."
            return
        }

        guard cleanedDetails.isEmpty == false else {
            detailsTouched = true
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func fieldStack<Content: View>(label: String, required: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if required {
                    Text("*")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
