import SwiftUI

struct ResourceImportReviewDecision: Identifiable {
    let reviewItem: ResourceImportReviewItem
    var shouldApply: Bool

    var id: UUID { reviewItem.id }
}

struct ResourceImportReviewSheet: View {
    @Binding var decisions: [ResourceImportReviewDecision]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localized("Validation ligne par ligne"))
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(localized("Tout conserver")) {
                        for index in decisions.indices where decisions[index].reviewItem.action == .update {
                            decisions[index].shouldApply = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Button(localized("Tout écraser")) {
                        for index in decisions.indices where decisions[index].reviewItem.action == .update {
                            decisions[index].shouldApply = true
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }

                List {
                    ForEach($decisions) { $decision in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(localized("Ligne \\(decision.reviewItem.sourceRowNumber)"))
                                    .font(.headline)
                                Text(decision.reviewItem.displayName)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(actionLabel(for: decision.reviewItem.action))
                                    .foregroundStyle(actionColor(for: decision.reviewItem.action))
                            }

                            if let firstRow = decision.reviewItem.duplicateOfRowNumber {
                                Label(
                                    AppLocalizer.localizedFormat(
                                        "Doublon de la ligne %d : les valeurs sont cumulées dans l'ordre du fichier.",
                                        language: appState.interfaceLanguage,
                                        firstRow
                                    ),
                                    systemImage: "doc.on.doc"
                                )
                                .font(.caption)
                                .foregroundStyle(SamouraiColorTheme.color(.healthOrange))
                            }

                            switch decision.reviewItem.action {
                            case .create, .update:
                                Toggle(
                                    decision.reviewItem.action == .update
                                        ? "Écraser les informations existantes avec l'import"
                                        : "Importer cette nouvelle ressource",
                                    isOn: $decision.shouldApply
                                )
                                    .toggleStyle(.checkbox)
                            case .noChange:
                                Text(localized("Aucune modification détectée."))
                                    .foregroundStyle(.secondary)
                            case .skipped:
                                Text(localized("Ligne ignorée (données insuffisantes)."))
                                    .foregroundStyle(.secondary)
                            }

                            if decision.reviewItem.changes.isEmpty == false {
                                ForEach(decision.reviewItem.changes) { change in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(change.fieldLabel)
                                            .font(.caption.weight(.semibold))
                                            .frame(width: 170, alignment: .leading)
                                        Text(change.oldValue.isEmpty ? "-" : change.oldValue)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(change.newValue.isEmpty ? "-" : change.newValue)
                                            .font(.caption.monospaced())
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
                .scrollIndicators(.visible)
            }
            .padding(16)
            .navigationTitle(localized("Revue d'import"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Appliquer")) {
                        onApply()
                    }
                    .disabled(decisions.contains(where: { ($0.reviewItem.action == .update || $0.reviewItem.action == .create) && $0.shouldApply }) == false)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var summaryText: String {
        let updates = decisions.filter { $0.reviewItem.action == .update }.count
        let creates = decisions.filter { $0.reviewItem.action == .create }.count
        let unchanged = decisions.filter { $0.reviewItem.action == .noChange }.count
        let skipped = decisions.filter { $0.reviewItem.action == .skipped }.count
        return "\(creates) création(s), \(updates) mise(s) à jour, \(unchanged) inchangée(s), \(skipped) ignorée(s)"
    }

    private func actionLabel(for action: ResourceImportReviewAction) -> String {
        switch action {
        case .create:
            "Création"
        case .update:
            "Écrasement"
        case .noChange:
            "Inchangé"
        case .skipped:
            "Ignoré"
        }
    }

    private func actionColor(for action: ResourceImportReviewAction) -> Color {
        switch action {
        case .create:
            .green
        case .update:
            .orange
        case .noChange:
            .secondary
        case .skipped:
            .secondary
        }
    }

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

