import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let primaryProjectName: String?

    @State private var isShowingDeleteConfirmation = false
    @State private var selectedTableID: AppTableID = .actions

    var body: some View {
        @Bindable var appState = appState
        ScrollView {
            VStack(alignment: .leading, spacing: SamouraiLayout.sectionSpacing) {
                SamouraiPageHeader(
                    eyebrow: "Configuration",
                    title: "Espace de travail",
                    subtitle: "Une configuration courte et lisible, pour garder l'écran centré sur l'action."
                )

                SamouraiSectionCard(
                    title: "Projet actif",
                    subtitle: "Les sous-sections projet utilisent le projet sélectionné dans la liste déroulante du haut."
                ) {
                    Text(primaryProjectName ?? "Aucun projet principal défini pour le moment.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SamouraiSectionCard(
                    title: "Typographie",
                    subtitle: "Ajuste la taille des textes affichés dans l'application."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Taille du texte", systemImage: "textformat.size")
                            Spacer()
                            Text(fontSizeLabel)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $appState.fontSizeOffset, in: -2...4, step: 1.0) {
                            Text("Taille")
                        } minimumValueLabel: {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "textformat.size.larger")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SamouraiSectionCard(
                    title: "Tableaux",
                    subtitle: "Colonnes visibles et ordre d'affichage pour les tableaux de l'application."
                ) {
                    TableColumnConfigurationPanel(selectedTableID: $selectedTableID)
                }

                SamouraiSectionCard(
                    title: "Debug",
                    subtitle: "Diagnostic des vues, entités, énumérations et données mobilisées par la fenêtre courante."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $appState.isDebugEnabled) {
                            Label("Mode debug activé", systemImage: "ladybug")
                        }

                        Toggle(isOn: $appState.debugKeepFullHistory) {
                            Label("Garder tout l'historique dans un fichier", systemImage: "tray.and.arrow.down")
                        }
                        .disabled(appState.isDebugEnabled == false)
                        .opacity(appState.isDebugEnabled ? 1 : 0.5)

                        if appState.isDebugEnabled, appState.debugKeepFullHistory {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chemin du fichier de debug")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 10) {
                                    TextField("Chemin", text: $appState.debugFilePath)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(1)
                                    Button("Choisir…") {
                                        if let newPath = promptForDebugFilePath(current: appState.debugFilePath) {
                                            appState.debugFilePath = newPath
                                        }
                                    }
                                    Button("Réinitialiser") {
                                        appState.debugFilePath = AppState.debugDefaultFilePath
                                    }
                                    .buttonStyle(.bordered)
                                }
                                Text("Valeur par défaut : \(AppState.debugDefaultFilePath)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                SamouraiSectionCard(
                    title: "Données",
                    subtitle: "Suppression irréversible de l'ensemble des données de l'instance."
                ) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Supprimer toutes les données de l'application", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(SamouraiLayout.pagePadding)
        }
        .scrollIndicators(.visible)
        .confirmationDialog(
            "Supprimer toutes les données ?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer définitivement", role: .destructive) {
                store.deleteAllData()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les données de l'application seront perdues. Cette action est irréversible. Effectuez une sauvegarde préalable via le module Sauvegardes si vous souhaitez pouvoir les récupérer.")
        }
    }

    private func promptForDebugFilePath(current: String) -> String? {
        let panel = NSSavePanel()
        panel.title = "Emplacement du fichier de debug"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.plainText, .data]
        panel.nameFieldStringValue = (current as NSString).lastPathComponent
        let directoryPath = ((current as NSString).expandingTildeInPath as NSString).deletingLastPathComponent
        if directoryPath.isEmpty == false {
            panel.directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        }
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        return url.path
    }

    private var fontSizeLabel: String {
        switch Int(appState.fontSizeOffset.rounded()) {
        case ..<(-1): return "Très petit"
        case -1: return "Petit"
        case 0: return "Normal"
        case 1: return "Grand"
        case 2: return "Très grand"
        case 3: return "Énorme"
        default: return "Maximum"
        }
    }
}

private struct TableColumnConfigurationPanel: View {
    @Environment(AppState.self) private var appState

    @Binding var selectedTableID: AppTableID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Tableau", selection: $selectedTableID) {
                ForEach(AppTableID.allCases) { tableID in
                    Label(tableID.title, systemImage: tableID.systemImage)
                        .tag(tableID)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 360, alignment: .leading)

            HStack(spacing: 10) {
                Label(selectedTableID.title, systemImage: selectedTableID.systemImage)
                    .font(.headline)
                Text(selectedTableID.subtitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(visibleColumnCount) / \(orderedColumns.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(orderedColumns.enumerated()), id: \.element.id) { index, column in
                    TableColumnConfigurationRow(
                        column: column,
                        isVisible: visibleColumnIDs.contains(column.id),
                        canHide: visibleColumnCount > 1 || visibleColumnIDs.contains(column.id) == false,
                        canMoveUp: index > 0,
                        canMoveDown: index < orderedColumns.count - 1,
                        onToggleVisibility: { isVisible in
                            appState.setTableColumnVisibility(
                                tableID: selectedTableID,
                                columnID: column.id,
                                isVisible: isVisible
                            )
                        },
                        onMoveUp: {
                            appState.moveTableColumn(tableID: selectedTableID, columnID: column.id, offset: -1)
                        },
                        onMoveDown: {
                            appState.moveTableColumn(tableID: selectedTableID, columnID: column.id, offset: 1)
                        }
                    )
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 260, maxHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SamouraiSurface.border, lineWidth: 1)
            }

            HStack {
                Spacer()
                Button {
                    appState.resetTableColumnConfiguration(tableID: selectedTableID)
                } label: {
                    Label("Réinitialiser", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    appState.showAllTableColumns(tableID: selectedTableID)
                } label: {
                    Label("Tout afficher", systemImage: "eye")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var configuration: TableColumnConfiguration {
        appState.tableColumnConfiguration(for: selectedTableID)
    }

    private var orderedColumns: [AppTableColumnDescriptor] {
        selectedTableID.orderedColumnDescriptors(for: configuration)
    }

    private var visibleColumnIDs: Set<String> {
        Set(configuration.visibleColumnIDs)
    }

    private var visibleColumnCount: Int {
        visibleColumnIDs.count
    }
}

private struct TableColumnConfigurationRow: View {
    let column: AppTableColumnDescriptor
    let isVisible: Bool
    let canHide: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggleVisibility: (Bool) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                column.title,
                isOn: Binding(
                    get: { isVisible },
                    set: { newValue in
                        onToggleVisibility(newValue)
                    }
                )
            )
            .toggleStyle(.switch)
            .disabled(isVisible && canHide == false)

            Spacer()

            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(canMoveUp == false)
                .help("Monter")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(canMoveDown == false)
                .help("Descendre")
            }
        }
        .padding(.vertical, 4)
    }
}
