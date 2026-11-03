import SwiftUI

private struct ResourceEvaluationDraft {
    var evaluatedAt: Date = .now
    var milestone: String = "Fin de Sprint"
    var evaluator: String = "Chef de Projet"
    var comment: String = ""
    var scores: [ResourceEvaluationCriterion: ResourceEvaluationScale] = Dictionary(
        uniqueKeysWithValues: ResourceEvaluationCriterion.allCases.map { ($0, .satisfaisant) }
    )
}

struct ResourceEvaluationPayload {
    let evaluatedAt: Date
    let milestone: String
    let evaluator: String
    let comment: String
    let criterionScores: [ResourceCriterionScore]
}

struct ResourceEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let resource: Resource
    let scopedProject: Project?
    let onSave: (ResourceEvaluationPayload) -> Void

    @State private var draft = ResourceEvaluationDraft()
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Contexte")) {
                    Text(resource.displayName)
                    DatePicker(localized("Date"), selection: $draft.evaluatedAt, displayedComponents: .date)
                    TextField(localized("Jalon / Milestone"), text: $draft.milestone)
                    TextField(localized("Évaluateur"), text: $draft.evaluator)
                    if let scopedProject {
                        Text(appState.localizedFormat("Projet: %@ • Phase: %@", scopedProject.name, scopedProject.phase.label.appLocalized(language: appState.interfaceLanguage)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(localized("Portée multi-projet (pondération standard)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(localized("Notation structurée (1..5)")) {
                    ForEach(ResourceEvaluationCriterion.allCases) { criterion in
                        Picker(criterion.label.appLocalized(language: appState.interfaceLanguage), selection: scoreBinding(for: criterion)) {
                            ForEach(ResourceEvaluationScale.allCases) { level in
                                Text(appState.localizedFormat("%d - %@", level.rawValue, level.label.appLocalized(language: appState.interfaceLanguage))).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section(localized("Commentaire justificatif (obligatoire)")) {
                    TextField(localized("Observations détaillées"), text: $draft.comment, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(appState.localized("Nouvelle évaluation"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        requestDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Enregistrer")) {
                        submit()
                    }
                    .disabled(draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 620)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
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

    private var snapshot: String {
        [
            String(draft.evaluatedAt.timeIntervalSinceReferenceDate),
            draft.milestone,
            draft.evaluator,
            draft.comment,
            ResourceEvaluationCriterion.allCases.map { "\($0.rawValue):\(draft.scores[$0]?.rawValue ?? 0)" }.joined(separator: ",")
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
        onSave(payload())
        dismiss()
    }

    private func scoreBinding(for criterion: ResourceEvaluationCriterion) -> Binding<ResourceEvaluationScale> {
        Binding(
            get: { draft.scores[criterion] ?? .satisfaisant },
            set: { draft.scores[criterion] = $0 }
        )
    }

    private func payload() -> ResourceEvaluationPayload {
        let criterionScores = ResourceEvaluationCriterion.allCases.map { criterion in
            ResourceCriterionScore(
                criterion: criterion,
                score: draft.scores[criterion] ?? .satisfaisant
            )
        }
        return ResourceEvaluationPayload(
            evaluatedAt: draft.evaluatedAt,
            milestone: draft.milestone,
            evaluator: draft.evaluator,
            comment: draft.comment,
            criterionScores: criterionScores
        )
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
