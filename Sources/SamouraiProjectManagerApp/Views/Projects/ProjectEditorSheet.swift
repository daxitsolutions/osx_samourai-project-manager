import SwiftUI

struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let project: Project?

    @State private var name: String
    @State private var summary: String
    @State private var sponsor: String
    @State private var manager: String
    @State private var phase: ProjectPhase
    @State private var health: ProjectHealth
    @State private var deliveryMode: DeliveryMode
    @State private var startDate: Date
    @State private var targetDate: Date
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    init(project: Project? = nil) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _summary = State(initialValue: project?.summary ?? "")
        _sponsor = State(initialValue: project?.sponsor ?? "")
        _manager = State(initialValue: project?.manager ?? "")
        _phase = State(initialValue: project?.phase ?? .cadrage)
        _health = State(initialValue: project?.health ?? .green)
        _deliveryMode = State(initialValue: project?.deliveryMode ?? .hybrid)
        _startDate = State(initialValue: project?.startDate ?? .now)
        _targetDate = State(initialValue: project?.targetDate ?? Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du projet", text: $name)
                TextField("Résumé opérationnel", text: $summary, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Sponsor", text: $sponsor)
                TextField("Chef de projet", text: $manager)

                Picker("Phase", selection: $phase) {
                    ForEach(ProjectPhase.allCases) { phase in
                        Text(phase.label.appLocalized(language: appState.interfaceLanguage)).tag(phase)
                    }
                }

                Picker("Santé", selection: $health) {
                    ForEach(ProjectHealth.allCases) { health in
                        Text(health.label.appLocalized(language: appState.interfaceLanguage)).tag(health)
                    }
                }

                Picker("Mode de delivery", selection: $deliveryMode) {
                    ForEach(DeliveryMode.allCases) { mode in
                        Text(mode.label.appLocalized(language: appState.interfaceLanguage)).tag(mode)
                    }
                }

                DatePicker("Date de démarrage", selection: $startDate, displayedComponents: .date)
                DatePicker("Date cible", selection: $targetDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "Nouveau projet" : "Modifier le projet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? "Créer" : "Enregistrer") {
                        save()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 430)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
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
            captureInitialSnapshotIfNeeded()
        }
    }

    private var formIsInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || targetDate < startDate
    }

    private var snapshot: String {
        [
            name,
            summary,
            sponsor,
            manager,
            phase.rawValue,
            health.rawValue,
            deliveryMode.rawValue,
            String(startDate.timeIntervalSinceReferenceDate),
            String(targetDate.timeIntervalSinceReferenceDate)
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
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedName.isEmpty == false else { return }
        if let project {
            store.updateProject(
                projectID: project.id,
                name: cleanedName,
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                sponsor: sponsor.trimmingCharacters(in: .whitespacesAndNewlines),
                manager: manager.trimmingCharacters(in: .whitespacesAndNewlines),
                phase: phase,
                health: health,
                deliveryMode: deliveryMode,
                startDate: startDate,
                targetDate: targetDate
            )
            appState.openProject(project.id)
        } else {
            let projectID = store.addProject(
                name: cleanedName,
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                sponsor: sponsor.trimmingCharacters(in: .whitespacesAndNewlines),
                manager: manager.trimmingCharacters(in: .whitespacesAndNewlines),
                phase: phase,
                health: health,
                deliveryMode: deliveryMode,
                startDate: startDate,
                targetDate: targetDate
            )
            appState.selectedProjectID = projectID
            appState.setPrimaryProject(projectID)
        }
        dismiss()
    }
}

struct RiskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID

    @State private var title = ""
    @State private var mitigation = ""
    @State private var owner = ""
    @State private var severity: RiskSeverity = .medium
    @State private var dueDate = Date.now
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Risque", text: $title)
                TextField("Mitigation", text: $mitigation, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Owner", text: $owner)

                Picker("Sévérité", selection: $severity) {
                    ForEach(RiskSeverity.allCases) { severity in
                        Text(severity.label.appLocalized(language: appState.interfaceLanguage)).tag(severity)
                    }
                }

                DatePicker("Date d'action cible", selection: $dueDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau risque")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        store.addRisk(
                            to: projectID,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            mitigation: mitigation.trimmingCharacters(in: .whitespacesAndNewlines),
                            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
                            severity: severity,
                            dueDate: dueDate
                        )
                        dismiss()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 360)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
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
            captureInitialSnapshotIfNeeded()
        }
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var snapshot: String {
        [
            title,
            mitigation,
            owner,
            severity.rawValue,
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
        store.addRisk(
            to: projectID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            mitigation: mitigation.trimmingCharacters(in: .whitespacesAndNewlines),
            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: severity,
            dueDate: dueDate
        )
        dismiss()
    }
}

struct DeliverableEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID

    @State private var title = ""
    @State private var details = ""
    @State private var owner = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Livrable", text: $title)
                TextField("Description", text: $details, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Owner", text: $owner)
                DatePicker("Échéance", selection: $dueDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau livrable")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        store.addDeliverable(
                            to: projectID,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
                            dueDate: dueDate
                        )
                        dismiss()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 340)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog("Fermer le formulaire ?", isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
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
            captureInitialSnapshotIfNeeded()
        }
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var snapshot: String {
        [
            title,
            details,
            owner,
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
        store.addDeliverable(
            to: projectID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate
        )
        dismiss()
    }
}
