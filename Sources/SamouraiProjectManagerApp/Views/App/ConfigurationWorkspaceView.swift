import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store
    @Environment(RESTAPIService.self) private var restAPIService

    let primaryProjectName: String?

    @State private var isShowingDeleteConfirmation = false
    @State private var selectedTableID: AppTableID = .actions
    @State private var restAPIPortText = String(AppState.defaultRESTAPIPort)

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
                    Text(primaryProjectName ?? localized("Aucun projet principal défini pour le moment."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SamouraiSectionCard(
                    title: "Typographie",
                    subtitle: "Ajuste la taille des textes affichés dans l'application."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(localized("Taille du texte"), systemImage: "textformat.size")
                            Spacer()
                            Text(localized(fontSizeLabelKey))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $appState.fontSizeOffset, in: -2...4, step: 1.0) {
                            Text(localized("Taille"))
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
                    title: "Préférences d'affichage",
                    subtitle: "Choisit la langue de l'interface et applique le changement sans redémarrage."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(localized("Langue de l'interface"), systemImage: "globe")
                            Spacer()
                            Picker(
                                localized("Langue de l'interface"),
                                selection: $appState.interfaceLanguage
                            ) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.localizedDisplayName(in: appState.interfaceLanguage))
                                        .tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 180)
                        }

                        Text(localized("Le changement de langue met à jour l'interface immédiatement."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SamouraiSectionCard(
                    title: "API REST",
                    subtitle: "Pilote le serveur local exposant le modèle de données en JSON."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { appState.isRESTAPIEnabled },
                                set: { setRESTAPIEnabled($0) }
                            )) {
                                Label(localized("Activer l'API REST"), systemImage: "network")
                            }
                            Spacer()
                            apiStatusBadge
                        }

                        HStack(spacing: 12) {
                            Label(localized("Port de l'API"), systemImage: "number")
                            Spacer()
                            TextField(localized("Port"), text: $restAPIPortText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)
                                .multilineTextAlignment(.trailing)
                                .onSubmit { applyRESTAPIPortText(restAPIPortText) }
                                .onChange(of: restAPIPortText) { _, newValue in
                                    applyRESTAPIPortText(newValue)
                                }
                        }

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 8) {
                            GridRow {
                                Text(localized("Format d'entrée"))
                                    .foregroundStyle(.secondary)
                                Text("JSON (application/json)")
                                    .fontWeight(.semibold)
                            }
                            GridRow {
                                Text(localized("Format de sortie"))
                                    .foregroundStyle(.secondary)
                                Text("JSON (application/json)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.caption)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(restAPIService.isRunning ? SamouraiColorTheme.color(.brandGreen) : SamouraiColorTheme.color(.dangerRed))
                                .frame(width: 8, height: 8)
                            Text("Statut : \(restAPIService.statusMessage)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)

                        if let errorMessage = restAPIService.lastErrorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(SamouraiColorTheme.color(.dangerRed))
                        }

                        Divider()

                        Text(localized("Objets concernés par le CRUD des API"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(restAPIObjectLabels, id: \.self) { label in
                                Label(label, systemImage: "curlybraces")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear {
                        restAPIPortText = String(appState.restAPIPort)
                    }
                    .onChange(of: appState.restAPIPort) { _, newPort in
                        if restAPIPortText != String(newPort) {
                            restAPIPortText = String(newPort)
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
                            Label(localized("Mode debug activé"), systemImage: "ladybug")
                        }

                        Toggle(isOn: $appState.debugKeepFullHistory) {
                            Label(localized("Garder tout l'historique dans un fichier"), systemImage: "tray.and.arrow.down")
                        }
                        .disabled(appState.isDebugEnabled == false)
                        .opacity(appState.isDebugEnabled ? 1 : 0.5)

                        if appState.isDebugEnabled, appState.debugKeepFullHistory {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(localized("Chemin du fichier de debug"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 10) {
                                    TextField(localized("Chemin"), text: $appState.debugFilePath)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(1)
                                    Button(localized("Choisir…")) {
                                        if let newPath = promptForDebugFilePath(current: appState.debugFilePath) {
                                            appState.debugFilePath = newPath
                                        }
                                    }
                                    Button(localized("Réinitialiser")) {
                                        appState.debugFilePath = AppState.debugDefaultFilePath
                                    }
                                    .buttonStyle(.bordered)
                                }
                                Text(
                                    AppLocalizer.localizedFormat(
                                        "Valeur par défaut : %@",
                                        language: appState.interfaceLanguage,
                                        AppState.debugDefaultFilePath
                                    )
                                )
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
                        Label(localized("Supprimer toutes les données de l'application"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(SamouraiLayout.pagePadding)
        }
        .scrollIndicators(.visible)
        .confirmationDialog(
            localized("Supprimer toutes les données ?"),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(localized("Supprimer définitivement"), role: .destructive) {
                store.deleteAllData()
            }
            Button(localized("Annuler"), role: .cancel) {}
        } message: {
            Text(localized("Toutes les données de l'application seront perdues. Cette action est irréversible. Effectuez une sauvegarde préalable via le module Sauvegardes si vous souhaitez pouvoir les récupérer."))
        }
    }

    private func promptForDebugFilePath(current: String) -> String? {
        let panel = NSSavePanel()
        panel.title = localized("Emplacement du fichier de debug")
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

    private var fontSizeLabelKey: String {
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

    @ViewBuilder
    private var apiStatusBadge: some View {
        Text(restAPIService.isRunning ? localized("ON") : localized("OFF"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(restAPIService.isRunning ? SamouraiColorTheme.color(.brandGreen) : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(restAPIService.isRunning ? SamouraiColorTheme.color(.brandGreen).opacity(0.12) : Color.secondary.opacity(0.12))
            )
    }

    private var restAPIObjectLabels: [String] {
        [
            "Meetings",
            "Projects",
            "Resources",
            "ResourceDirectory",
            "Risks",
            "PMActions",
            "Decisions",
            "Events",
            "Deliverables",
            "ScopeIn",
            "ScopeOut"
        ]
    }

    private func setRESTAPIEnabled(_ isEnabled: Bool) {
        guard isEnabled else {
            appState.isRESTAPIEnabled = false
            return
        }

        guard validateRESTAPIPort(appState.restAPIPort) else {
            appState.isRESTAPIEnabled = false
            return
        }

        appState.isRESTAPIEnabled = true
    }

    private func applyRESTAPIPortText(_ rawValue: String) {
        let digits = rawValue.filter(\.isNumber)
        if digits != rawValue {
            restAPIPortText = digits
            return
        }

        guard let port = Int(digits) else {
            return
        }

        guard AppState.isValidRESTAPIPort(port) else {
            restAPIService.reportConfigurationError(localized("Le port doit être compris entre 1024 et 65535."))
            return
        }

        guard port != appState.restAPIPort else {
            return
        }

        guard validateRESTAPIPort(port) else {
            return
        }

        appState.restAPIPort = port
    }

    private func validateRESTAPIPort(_ port: Int) -> Bool {
        if restAPIService.activePort == port {
            return true
        }

        guard RESTAPIService.isPortAvailable(port) else {
            restAPIService.reportConfigurationError(
                AppLocalizer.localizedFormat(
                    "Le port %@ est déjà utilisé par un autre processus.",
                    language: appState.interfaceLanguage,
                    "\(port)"
                )
            )
            return false
        }

        return true
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct TableColumnConfigurationPanel: View {
    @Environment(AppState.self) private var appState

    @Binding var selectedTableID: AppTableID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(localized("Tableau"), selection: $selectedTableID) {
                ForEach(AppTableID.allCases) { tableID in
                    Label(localized(tableID.title), systemImage: tableID.systemImage)
                        .tag(tableID)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 360, alignment: .leading)

            HStack(spacing: 10) {
                Label(localized(selectedTableID.title), systemImage: selectedTableID.systemImage)
                    .font(.headline)
                Text(localized(selectedTableID.subtitle))
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
                    Label(localized("Réinitialiser"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    appState.showAllTableColumns(tableID: selectedTableID)
                } label: {
                    Label(localized("Tout afficher"), systemImage: "eye")
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct TableColumnConfigurationRow: View {
    @Environment(AppState.self) private var appState

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
                localized(column.title),
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
                .help(localized("Monter"))

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(canMoveDown == false)
                .help(localized("Descendre"))
            }
        }
        .padding(.vertical, 4)
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
