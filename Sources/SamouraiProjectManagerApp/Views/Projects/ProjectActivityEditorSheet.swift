import SwiftUI

struct ProjectActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID
    let activity: ProjectActivity?
    let preferredScenarioID: UUID?
    let linkedActionIDs: [UUID]
    let linkedDeliverableIDs: [UUID]

    @State private var title: String
    @State private var isDateless: Bool
    @State private var estimatedStartDate: Date
    @State private var estimatedEndDate: Date
    @State private var includeActualEndDate: Bool
    @State private var actualEndDate: Date
    @State private var selectedActionIDs: Set<UUID>
    @State private var selectedDeliverableIDs: Set<UUID>
    @State private var selectedPredecessorIDs: Set<UUID>
    @State private var parentActivityID: UUID?
    @State private var hierarchyLevel: ActivityHierarchyLevel
    @State private var isMilestone: Bool
    @State private var actionSelectionQuery = ""
    @State private var predecessorSelectionQuery = ""
    @State private var parentSelectionQuery = ""
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false
    @State private var titleTouched = false

    init(
        projectID: UUID,
        activity: ProjectActivity?,
        initialParentActivityID: UUID? = nil,
        preferredScenarioID: UUID? = nil,
        linkedActionIDs: [UUID],
        linkedDeliverableIDs: [UUID]
    ) {
        self.projectID = projectID
        self.activity = activity
        self.preferredScenarioID = preferredScenarioID
        self.linkedActionIDs = linkedActionIDs
        self.linkedDeliverableIDs = linkedDeliverableIDs
        _title = State(initialValue: activity?.title ?? "")
        _isDateless = State(initialValue: activity?.isDateless ?? false)
        _estimatedStartDate = State(initialValue: activity?.estimatedStartDate ?? .now)
        _estimatedEndDate = State(initialValue: activity?.estimatedEndDate ?? (Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now))
        _includeActualEndDate = State(initialValue: activity?.actualEndDate != nil)
        _actualEndDate = State(initialValue: activity?.actualEndDate ?? .now)
        _selectedActionIDs = State(initialValue: Set(linkedActionIDs))
        _selectedDeliverableIDs = State(initialValue: Set(linkedDeliverableIDs))
        _selectedPredecessorIDs = State(initialValue: Set(activity?.predecessorActivityIDs ?? []))
        _parentActivityID = State(initialValue: activity?.parentActivityID ?? initialParentActivityID)
        _hierarchyLevel = State(initialValue: activity?.hierarchyLevel ?? .activityTask)
        _isMilestone = State(initialValue: activity?.isMilestone ?? false)
    }

    private var resolvedScenarioID: UUID? {
        activity?.scenarioID ?? preferredScenarioID ?? store.defaultPlanningScenarioID(for: projectID)
    }

    var body: some View {
        let projectActions = store.actions.filter { $0.projectID == projectID }
        let resolvedScenario = store
            .planningScenarios(for: projectID)
            .first { $0.id == resolvedScenarioID }
        let projectActivities = store.allActivities(for: projectID).filter {
            $0.scenarioID == resolvedScenarioID && $0.id != activity?.id
        }
        let parentCandidates = projectActivities.filter { $0.hierarchyLevel.sortRank < hierarchyLevel.sortRank }
        let actionLinkingIsAvailable = resolvedScenarioID == store.defaultPlanningScenarioID(for: projectID)
        let projectDeliverables = store.project(with: projectID)?.deliverables ?? []
        let majorDeliverables = projectDeliverables.filter(\.isMainDeliverable)
        let titleIsEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Métadonnées ──────────────────────────────────────
                    formSection(title: localized("Métadonnées activité")) {
                        VStack(alignment: .leading, spacing: 16) {
                            fieldStack(label: localized("Titre de l'activité"), required: true) {
                                TextField(localized("Nommez l'activité..."), text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .overlay(alignment: .trailing) {
                                        if titleTouched && titleIsEmpty {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .padding(.trailing, 6)
                                        }
                                    }
                                    .onSubmit { titleTouched = true }
                                if titleTouched && titleIsEmpty {
                                    Label(localized("Le titre est obligatoire"), systemImage: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            if let resolvedScenario {
                                fieldStack(label: localized("Scénario")) {
                                    Text(resolvedScenario.name)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(.separator, lineWidth: 0.5)
                                        }
                                }
                            }

                            HStack(alignment: .top, spacing: 16) {
                                fieldStack(label: localized("Type hiérarchique")) {
                                    Picker("", selection: $hierarchyLevel) {
                                        ForEach(ActivityHierarchyLevel.allCases) { level in
                                            Text(level.label.appLocalized(language: appState.interfaceLanguage)).tag(level)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                fieldStack(label: localized("Activité parente")) {
                                    SearchableSingleSelectDropdown(
                                        title: localized("Sélectionner..."),
                                        placeholder: localized("Rechercher une activité parente"),
                                        items: parentCandidates,
                                        selectedID: $parentActivityID,
                                        query: $parentSelectionQuery,
                                        itemLabel: { $0.displayTitle }
                                    )
                                }
                            }
                        }
                    }

                    // ── Planification ────────────────────────────────────
                    formSection(title: localized("Planification")) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(localized("Pas de date (activité chapeau)"), isOn: $isDateless)

                            if isDateless {
                                Label(
                                    localized("Cette activité regroupe d'autres activités sans avoir de dates propres."),
                                    systemImage: "calendar.badge.minus"
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            } else {
                                Toggle(localized("Marquer comme jalon"), isOn: $isMilestone)

                                Divider()

                                if isMilestone {
                                    fieldStack(label: localized("Date de fin (jalon)")) {
                                        DatePicker("", selection: $estimatedEndDate, displayedComponents: .date)
                                            .labelsHidden()
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 16) {
                                        fieldStack(label: localized("Date de début estimée")) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                DatePicker("", selection: $estimatedStartDate, displayedComponents: .date)
                                                    .labelsHidden()
                                                if !selectedPredecessorIDs.isEmpty {
                                                    Label(
                                                        localized("Positionnée depuis le prédécesseur"),
                                                        systemImage: "link"
                                                    )
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        fieldStack(label: localized("Date de fin estimée")) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                DatePicker("", selection: $estimatedEndDate, displayedComponents: .date)
                                                    .labelsHidden()
                                                if estimatedEndDate < estimatedStartDate {
                                                    Label(
                                                        localized("La fin doit être après le début"),
                                                        systemImage: "exclamationmark.triangle.fill"
                                                    )
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                                }
                                            }
                                        }
                                    }
                                }

                                Divider()

                                Toggle(localized("Fin réelle renseignée"), isOn: $includeActualEndDate)
                                if includeActualEndDate {
                                    fieldStack(label: localized("Date de fin réelle")) {
                                        DatePicker("", selection: $actualEndDate, displayedComponents: .date)
                                            .labelsHidden()
                                    }
                                }
                            }
                        }
                    }

                    // ── Actions rattachées ───────────────────────────────
                    formSection(title: localized("Actions rattachées")) {
                        if !actionLinkingIsAvailable {
                            infoText(localized("Les rattachements d'actions restent pilotés sur le scénario principal pour éviter les croisements entre scénarios."))
                        } else if projectActions.isEmpty {
                            infoText(localized("Aucune action disponible pour ce projet."))
                        } else {
                            SearchableMultiSelectDropdown(
                                title: localized("Sélectionner les actions"),
                                placeholder: localized("Rechercher une action"),
                                items: projectActions,
                                selectedIDs: $selectedActionIDs,
                                query: $actionSelectionQuery,
                                itemLabel: { $0.displayTitle }
                            )
                        }
                    }

                    // ── Livrables ────────────────────────────────────────
                    formSection(title: localized("Livrables justifiés par l'activité")) {
                        if majorDeliverables.isEmpty {
                            infoText(localized("Aucun livrable principal disponible dans le scope."))
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(majorDeliverables) { deliverable in
                                    Toggle(
                                        deliverable.title,
                                        isOn: Binding(
                                            get: { selectedDeliverableIDs.contains(deliverable.id) },
                                            set: { isSelected in
                                                if isSelected { selectedDeliverableIDs.insert(deliverable.id) }
                                                else { selectedDeliverableIDs.remove(deliverable.id) }
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }

                    // ── Dépendances ──────────────────────────────────────
                    formSection(title: localized("Dépendances (A terminé avant B)")) {
                        if projectActivities.isEmpty {
                            infoText(localized("Aucune autre activité disponible."))
                        } else {
                            SearchableMultiSelectDropdown(
                                title: localized("Sélectionner les dépendances"),
                                placeholder: localized("Rechercher une activité"),
                                items: projectActivities,
                                selectedIDs: $selectedPredecessorIDs,
                                query: $predecessorSelectionQuery,
                                itemLabel: { $0.displayTitle }
                            )
                        }
                    }

                }
                .padding(24)
            }
            .navigationTitle(activity == nil ? "Nouvelle activité" : "Modifier activité")
            .onChange(of: isMilestone) { _, isNowMilestone in
                if isNowMilestone {
                    isDateless = false
                    estimatedStartDate = estimatedEndDate
                }
            }
            .onChange(of: isDateless) { _, isNowDateless in
                if isNowDateless {
                    isMilestone = false
                    includeActualEndDate = false
                }
            }
            .onChange(of: selectedPredecessorIDs) { _, newIDs in
                guard !newIDs.isEmpty, !isMilestone else { return }
                let allActivities = store.allActivities(for: projectID).filter {
                    $0.scenarioID == resolvedScenarioID && $0.id != activity?.id
                }
                if let latestEnd = allActivities
                    .filter({ newIDs.contains($0.id) })
                    .map(\.estimatedEndDate)
                    .max()
                {
                    estimatedStartDate = latestEnd
                }
            }
            .onChange(of: hierarchyLevel) { _, _ in
                if let parentActivityID,
                   parentCandidates.contains(where: { $0.id == parentActivityID }) == false {
                    self.parentActivityID = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(activity == nil ? localized("Créer") : localized("Enregistrer")) {
                        titleTouched = true
                        guard !formIsInvalid else { return }
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if !formIsInvalid {
                Button(localized("Enregistrer")) { submit() }
            }
            Button(localized("Ignorer les modifications"), role: .destructive) { dismiss() }
            Button(localized("Continuer l'édition"), role: .cancel) {}
        } message: {
            Text(localized("Les informations déjà saisies peuvent être enregistrées ou abandonnées."))
        }
        .onAppear {
            captureInitialSnapshotIfNeeded()
        }
    }

    // ── Helpers UI ───────────────────────────────────────────────────────

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
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
        VStack(alignment: .leading, spacing: 6) {
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

    @ViewBuilder
    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    // ── Logique ──────────────────────────────────────────────────────────

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (!isDateless && !isMilestone && estimatedEndDate < estimatedStartDate)
    }

    private var snapshot: String {
        [
            title,
            isDateless ? "dateless" : String(estimatedStartDate.timeIntervalSinceReferenceDate),
            isDateless ? "dateless" : String(estimatedEndDate.timeIntervalSinceReferenceDate),
            isDateless ? "0" : (includeActualEndDate ? "1" : "0"),
            isDateless ? "0" : String(actualEndDate.timeIntervalSinceReferenceDate),
            selectedActionIDs.map(\.uuidString).sorted().joined(separator: ","),
            selectedDeliverableIDs.map(\.uuidString).sorted().joined(separator: ","),
            selectedPredecessorIDs.map(\.uuidString).sorted().joined(separator: ","),
            parentActivityID?.uuidString ?? "",
            hierarchyLevel.rawValue,
            isDateless ? "dateless" : (isMilestone ? "1" : "0"),
            actionSelectionQuery,
            predecessorSelectionQuery,
            parentSelectionQuery
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
        let finalEstimatedStartDate = (!isDateless && isMilestone) ? estimatedEndDate : estimatedStartDate
        let finalActualEndDate = (!isDateless && includeActualEndDate) ? actualEndDate : nil
        if let activity {
            store.updateActivity(
                activityID: activity.id,
                title: title,
                isDateless: isDateless,
                estimatedStartDate: finalEstimatedStartDate,
                estimatedEndDate: estimatedEndDate,
                actualEndDate: finalActualEndDate,
                linkedActionIDs: Array(selectedActionIDs),
                predecessorActivityIDs: Array(selectedPredecessorIDs),
                isMilestone: isDateless ? false : isMilestone,
                hierarchyLevel: hierarchyLevel,
                parentActivityID: parentActivityID,
                linkedDeliverableIDs: Array(selectedDeliverableIDs)
            )
        } else {
            _ = store.addActivity(
                projectID: projectID,
                scenarioID: resolvedScenarioID,
                parentActivityID: parentActivityID,
                hierarchyLevel: hierarchyLevel,
                title: title,
                isDateless: isDateless,
                estimatedStartDate: finalEstimatedStartDate,
                estimatedEndDate: estimatedEndDate,
                actualEndDate: finalActualEndDate,
                linkedActionIDs: Array(selectedActionIDs),
                predecessorActivityIDs: Array(selectedPredecessorIDs),
                isMilestone: isDateless ? false : isMilestone,
                linkedDeliverableIDs: Array(selectedDeliverableIDs)
            )
        }
        dismiss()
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
