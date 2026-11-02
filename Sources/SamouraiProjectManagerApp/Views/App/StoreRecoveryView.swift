import SwiftUI

struct StoreRecoveryView: View {
    let message: String
    let filePath: String
    let onRetry: () -> Void
    let onRestore: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(appState.localized("Récupération des données"), systemImage: "externaldrive.badge.exclamationmark")
                .font(.title2.bold())
            Text(appState.localized("Les données n'ont pas pu être chargées. Les modifications sont bloquées pour éviter de perdre tes nouvelles saisies."))
            Text(message)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(filePath)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Text(appState.localized("Le fichier existant est conservé. Corrige-le puis réessaie, ou restaure une sauvegarde. Une copie du fichier rejeté sera conservée dans recovery-backups avant la restauration."))
            HStack {
                Button(appState.localized("Réessayer le chargement"), action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button(appState.localized("Restaurer une sauvegarde"), action: onRestore)
            }
        }
        .padding(32)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
