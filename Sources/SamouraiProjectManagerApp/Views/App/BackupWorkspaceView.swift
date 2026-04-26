import SwiftUI

struct BackupWorkspaceView: View {
    let primaryProjectName: String?
    let onExportBackup: () -> Void
    let onImportBackup: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SamouraiLayout.sectionSpacing) {
                SamouraiPageHeader(
                    eyebrow: "Sauvegardes",
                    title: "Sauvegardes et restaurations",
                    subtitle: "Les opérations de sauvegarde ont leur propre page pour éviter de les cacher dans un menu secondaire."
                )

                SamouraiSectionCard(
                    title: "État courant",
                    subtitle: "La sauvegarde capture l'état complet de l'application au moment de l'export."
                ) {
                    Text(primaryProjectName.map { "Projet actif actuel: \($0)" } ?? "Aucun projet actif sélectionné.")
                        .foregroundStyle(.secondary)
                }

                SamouraiSectionCard(
                    title: "Actions",
                    subtitle: "Exporter avant une restauration ou avant une évolution importante reste la pratique la plus sûre."
                ) {
                    HStack(spacing: 12) {
                        Button(action: onExportBackup) {
                            Label(localized("Sauvegarder l'état complet"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onImportBackup) {
                            Label(localized("Restaurer depuis un backup"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(SamouraiLayout.pagePadding)
        }
        .scrollIndicators(.visible)
    }

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
