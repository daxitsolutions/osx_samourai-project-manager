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

        NavigationStack {
            Form {
                Section(localized("Métadonnées activité")) {
                    TextField(localized("Titre de l'activité"), text: $title)
                    if let resolvedScenario {
                        LabeledContent("Scénario") {
                            Text(resolvedScenario.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker(localized("Type hiérarchique"), selection: $hierarchyLevel) {
                        ForEach(ActivityHierarchyLevel.allCases) { level in
                            Text(level.label.appLocalized(language: appState.interfaceLanguage)).tag(level)
                        }
                    }
                    SearchableSingleSelectDropdown(
                        title: "Activité parente",
                        placeholder: "Rechercher une activité parente",
                        items: parentCandidates,
                        selectedID: $parentActivityID,
                        query: $parentSelectionQuery,
                        itemLabel: { $0.displayTitle }
                    )
                    Toggle(localized("Pas de date (activité chapeau)"), isOn: $isDateless)
                    if isDateless {
                        Label(localized("Cette activité regroupe d'autres activités sans avoir de dates propres."), systemImage: "calendar.badge.minus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle(localized("Marquer comme jalon"), isOn: $isMilestone)
                        if isMilestone {
                            DatePicker(localized("Date de fin (jalon)"), selection: $estimatedEndDate, displayedComponents: .date)
                        } else {
                            DatePicker(localized("Date de début estimée"), selection: $estimatedStartDate, displayedComponents: .date)
                            if !selectedPredecessorIDs.isEmpty {
                                Label(localized("Date positionnée depuis le prédécesseur"), systemImage: "link")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            DatePicker(localized("Date de fin estimée"), selection: $estimatedEndDate, displayedComponents: .date)
                        }
                        Toggle(localized("Fin réelle renseignée"), isOn: $includeActualEndDate)
                        if includeActualEndDate {
                            DatePicker(localized("Date de fin réelle"), selection: $actualEndDate, displayedComponents: .date)
                        }
                    }
                }

                Section(localized("Actions rattachées")) {
                    if actionLinkingIsAvailable == false {
                        Text(localized("Les rattachements d'actions restent pilotés sur le scénario principal pour éviter les croisements entre scénarios."))
                            .foregroundStyle(.secondary)
                    } else if projectActions.isEmpty {
                        Text(localized("Aucune action disponible pour ce projet."))
                            .foregroundStyle(.secondary)
                    } else {
                        SearchableMultiSelectDropdown(
                            title: "Sélectionner les actions",
                            placeholder: "Rechercher une action",
                            items: projectActions,
                            selectedIDs: $selectedActionIDs,
                            query: $actionSelectionQuery,
                            itemLabel: { $0.displayTitle }
                        )
                    }
                }

                Section(localized("Livrables justifiés par l'activité")) {
                    let projectDeliverables = store.project(with: projectID)?.deliverables ?? []
                    let majorDeliverables = projectDeliverables.filter(\.isMainDeliverable)
                    if majorDeliverables.isEmpty {
                        Text(localized("Aucun livrable principal disponible dans le scope."))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(majorDeliverables) { deliverable in
                            Toggle(
                                deliverable.title,
                                isOn: Binding(
                                    get: { selectedDeliverableIDs.contains(deliverable.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedDeliverableIDs.insert(deliverable.id)
                                        } else {
                                            selectedDeliverableIDs.remove(deliverable.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }

                Section(localized("Dépendances (A terminé avant B)")) {
                    if projectActivities.isEmpty {
                        Text(localized("Aucune autre activité disponible."))
                            .foregroundStyle(.secondary)
                    } else {
                        SearchableMultiSelectDropdown(
                            title: "Sélectionner les dépendances",
                            placeholder: "Rechercher une activité",
                            items: projectActivities,
                            selectedIDs: $selectedPredecessorIDs,
                            query: $predecessorSelectionQuery,
                            itemLabel: { $0.displayTitle }
                        )
                    }
                }
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
                    Button(activity == nil ? "Créer" : "Enregistrer") {
                        submit()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 520)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
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
            captureInitialSnapshotIfNeeded()
        }
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (!isDateless && isMilestone == false && estimatedEndDate < estimatedStartDate)
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
