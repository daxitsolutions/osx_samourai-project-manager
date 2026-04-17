import SwiftUI

struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var name = ""
    @State private var summary = ""
    @State private var sponsor = ""
    @State private var manager = ""
    @State private var phase: ProjectPhase = .cadrage
    @State private var health: ProjectHealth = .green
    @State private var deliveryMode: DeliveryMode = .hybrid
    @State private var startDate = Date.now
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

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
                        Text(phase.label).tag(phase)
                    }
                }

                Picker("Santé", selection: $health) {
                    ForEach(ProjectHealth.allCases) { health in
                        Text(health.label).tag(health)
                    }
                }

                Picker("Mode de delivery", selection: $deliveryMode) {
                    ForEach(DeliveryMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                DatePicker("Date de démarrage", selection: $startDate, displayedComponents: .date)
                DatePicker("Date cible", selection: $targetDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau projet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let projectID = store.addProject(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
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
                        dismiss()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 430)
    }

    private var formIsInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sponsor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || manager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || targetDate < startDate
    }
}

struct RiskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID

    @State private var title = ""
    @State private var mitigation = ""
    @State private var owner = ""
    @State private var severity: RiskSeverity = .medium
    @State private var dueDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                TextField("Risque", text: $title)
                TextField("Mitigation", text: $mitigation, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Owner", text: $owner)

                Picker("Sévérité", selection: $severity) {
                    ForEach(RiskSeverity.allCases) { severity in
                        Text(severity.label).tag(severity)
                    }
                }

                DatePicker("Date d'action cible", selection: $dueDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau risque")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
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
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        dismiss()
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
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
