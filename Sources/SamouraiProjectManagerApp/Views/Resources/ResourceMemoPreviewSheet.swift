import SwiftUI

struct ResourceMemoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let resource: Resource

    private var memo: ResourceMemo { resource.memo }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.localizedFormat("Fiche de poste - Ressource Humaine : %@", display(memo.functionName, fallback: resource.displayPrimaryRole)))
                            .font(.title2.weight(.semibold))
                        Text(resource.displayName)
                            .foregroundStyle(.secondary)
                    }

                    previewSection(title: "1. Identité & mission", rows: [
                        ("Fonction", display(memo.function, fallback: resource.displayPrimaryRole)),
                        ("Titulaire", display(memo.holder, fallback: resource.displayName)),
                        ("Reporte à", display(memo.reportsTo, fallback: resource.responsableOperationnel ?? resource.responsableInterne ?? "")),
                        ("Mission principale", memo.mainMission)
                    ])

                    previewSection(title: "2. Responsabilités clés & livrables attendus", rows: [
                        ("Responsable de", memo.responsibleFor),
                        ("Livrables", memo.deliverables)
                    ])

                    previewSection(title: "3. Frontières du rôle", rows: [
                        ("Ce que je fais", memo.whatIDo),
                        ("Ce que je fais mais que je ne devrais pas faire", memo.whatIDoButShouldNot),
                        ("Ce que je ne fais pas", memo.whatIDoNotDo)
                    ])

                    previewSection(title: "4. Interdépendances", rows: [
                        ("J’ai besoin de", memo.needs),
                        ("Je fournis à", memo.providesTo)
                    ])

                    previewSection(title: "5. Infos pratiques", rows: [
                        ("Outils principaux", display(memo.mainTools, fallback: resource.resourceCalendar ?? "")),
                        ("Taux d’occupation actuel sur le projet", display(memo.currentProjectOccupancyRate, fallback: resource.allocationLabel)),
                        ("Date de mise à jour", memo.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                    ])
                }
                .padding(24)
            }
            .navigationTitle(appState.localized("Mémo ressource"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized("Fermer")) { dismiss() }
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 640, idealHeight: 760)
    }

    @ViewBuilder
    private func previewSection(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.localized(title))
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.localized(label))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(display(value))
                            .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func display(_ value: String, fallback: String = "-") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { return trimmed }
        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "-" : fallback
    }
}

