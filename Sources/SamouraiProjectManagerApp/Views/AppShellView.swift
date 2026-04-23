import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class AppShellDebugLogTracker {
    static let shared = AppShellDebugLogTracker()
    var lastSignature: String = ""
}

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var backupDocument: SamouraiBackupDocument?
    @State private var backupFilename = "samourai-backup"
    @State private var backupFeedbackMessage: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            VStack(spacing: 0) {
                selectedSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.isDebugEnabled {
                    SamouraiDebugPanel(
                        context: debugContext,
                        isHistoryEnabled: appState.debugKeepFullHistory,
                        historyFilePath: appState.debugKeepFullHistory ? appState.debugFilePath : nil
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .samouraiCanvasBackground()
            .onAppear { logDebugContextIfNeeded() }
            .onChange(of: debugContext.signature) { _, _ in logDebugContextIfNeeded() }
            .onChange(of: appState.isDebugEnabled) { _, enabled in
                if enabled { logDebugContextIfNeeded() }
            }
            .onChange(of: appState.debugKeepFullHistory) { _, _ in logDebugContextIfNeeded() }
        }
        .navigationSplitViewStyle(.balanced)
        .samouraiCanvasBackground()
        .environment(\.dynamicTypeSize, appState.dynamicTypeSize)
        .task {
            await store.loadIfNeeded()
            ensureDefaultProjectSelection()
        }
        .onChange(of: store.projects.map(\.id)) { _, _ in
            ensureDefaultProjectSelection()
        }
        .toolbar {
            if currentSection.showsProjectPicker {
                ToolbarItem(placement: .navigation) {
                    projectScopePicker
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(currentSection.title)
                        .font(.headline)
                    Text(toolbarSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fileExporter(
            isPresented: $isShowingBackupExporter,
            document: backupDocument,
            contentType: SamouraiBackupContentType.type,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                backupFeedbackMessage = "Sauvegarde exportée avec succès."
            case .failure(let error):
                backupFeedbackMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: [SamouraiBackupContentType.type, .json],
            allowsMultipleSelection: false
        ) { result in
            handleBackupImport(result)
        }
        .alert("Action impossible", isPresented: Binding(
            get: { store.lastErrorMessage != nil },
            set: { if $0 == false { store.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastErrorMessage ?? "Une erreur inconnue s'est produite.")
        }
        .alert("Sauvegarde / restauration", isPresented: Binding(
            get: { backupFeedbackMessage != nil },
            set: { if $0 == false { backupFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupFeedbackMessage ?? "")
        }
        .sheet(item: Binding(
            get: { appState.activeImportTracker },
            set: { tracker in
                if tracker == nil, let activeTracker = appState.activeImportTracker {
                    appState.clearImportProgress(activeTracker)
                }
            }
        )) { tracker in
            SamouraiImportProgressSheet(
                tracker: tracker,
                onCancel: {
                    tracker.cancel()
                }
            )
            .interactiveDismissDisabled()
        }
    }

    private var sidebarView: some View {
        List {
            Section(AppSectionGroup.portfolio.title) {
                sidebarButton(for: .projects)
            }

            Section(AppSectionGroup.project.title) {
                if let primaryProjectName {
                    Text(primaryProjectName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                } else {
                    Text("Choisir un projet en haut de page")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                }

                ForEach(projectSections) { section in
                    sidebarButton(for: section)
                }
            }

            Section(AppSectionGroup.directory.title) {
                sidebarButton(for: .resourceDirectory)
            }

            Section(AppSectionGroup.configuration.title) {
                sidebarButton(for: .configuration)
            }

            Section(AppSectionGroup.backups.title) {
                sidebarButton(for: .backups)
            }
        }
        .navigationTitle("Samourai")
        .navigationSplitViewColumnWidth(min: 248, ideal: 284, max: 320)
        .listStyle(.sidebar)
        .scrollIndicators(.visible)
        .scrollContentBackground(.hidden)
        .background(SamouraiSurface.sidebar)
    }

    private func sidebarButton(for section: AppSection) -> some View {
        Button {
            appState.selectedSection = section
        } label: {
            AppSidebarSectionRow(
                section: section,
                isSelected: currentSection == section
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowBackground(Color.clear)
    }

    private var currentSection: AppSection {
        appState.selectedSection ?? .dashboard
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch currentSection {
        case .dashboard:
            DashboardView()
        case .reporting:
            ReportingWorkspaceView()
        case .projects:
            ProjectWorkspaceView()
        case .resources:
            ResourceWorkspaceView()
        case .resourceDirectory:
            ResourceWorkspaceView(scopeMode: .globalDirectory)
        case .configuration:
            ConfigurationWorkspaceView(primaryProjectName: primaryProjectName)
        case .backups:
            BackupWorkspaceView(
                primaryProjectName: primaryProjectName,
                onExportBackup: exportBackup,
                onImportBackup: { isShowingBackupImporter = true }
            )
        case .testing:
            TestingWorkspaceView()
        case .risks:
            RiskRegisterView()
        case .deliverables:
            DeliverableBoardView()
        case .events:
            EventWorkspaceView()
        case .actions:
            ActionWorkspaceView()
        case .meetings:
            MeetingWorkspaceView()
        case .decisions:
            DecisionWorkspaceView()
        case .planning:
            PlanningWorkspaceView()
        }
    }

    private var toolbarSubtitle: String {
        if currentSection.showsProjectPicker, let primaryProjectName {
            return primaryProjectName
        }
        return currentSection.summary
    }

    private var projectSections: [AppSection] {
        [
            .dashboard,
            .planning,
            .actions,
            .events,
            .meetings,
            .deliverables,
            .resources,
            .risks,
            .decisions,
            .reporting
        ]
    }

    private var primaryProjectName: String? {
        guard let primaryProjectID = appState.resolvedPrimaryProjectID(in: store),
              let project = store.project(with: primaryProjectID) else {
            return nil
        }
        return project.name
    }

    @ViewBuilder
    private var projectScopePicker: some View {
        HStack(spacing: 8) {
            Label("Projet", systemImage: "target")
                .foregroundStyle(.secondary)

            if store.projects.isEmpty {
                Text("Aucun projet")
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "Projet principal",
                    selection: Binding(
                        get: {
                            appState.resolvedPrimaryProjectID(in: store) ?? store.projects[0].id
                        },
                        set: { appState.setPrimaryProject($0) }
                    )
                ) {
                    ForEach(store.projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 220)
            }
        }
    }

    private func exportBackup() {
        do {
            let data = try store.exportBackupData()
            backupDocument = SamouraiBackupDocument(data: data)
            backupFilename = "samourai-backup-\(Date.now.formatted(.dateTime.year().month().day()))"
            isShowingBackupExporter = true
        } catch {
            backupFeedbackMessage = error.localizedDescription
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else {
            if case .failure(let error) = result {
                backupFeedbackMessage = error.localizedDescription
            }
            return
        }

        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let restoreResult = try store.restoreBackupData(data)
            backupFeedbackMessage = """
            Restauration terminée : \(restoreResult.summary)
            Backup exporté le \(restoreResult.exportedAt.formatted(date: .abbreviated, time: .shortened)) depuis la version \(restoreResult.sourceAppVersion).
            """
        } catch {
            backupFeedbackMessage = error.localizedDescription
        }
    }

    private var debugContext: SamouraiDebugContext {
        SamouraiDebugContextFactory.make(for: currentSection, appState: appState, store: store)
    }

    private func logDebugContextIfNeeded() {
        guard appState.isDebugEnabled, appState.debugKeepFullHistory else { return }
        let context = debugContext
        let signature = context.signature
        if signature == AppShellDebugLogTracker.shared.lastSignature { return }
        AppShellDebugLogTracker.shared.lastSignature = signature
        store.appendDebugLog(filePath: appState.debugFilePath, entry: context.formattedLogEntry())
    }

    private func ensureDefaultProjectSelection() {
        guard let firstProjectID = store.projects.first?.id else {
            appState.setPrimaryProject(nil)
            appState.selectedProjectID = nil
            return
        }

        if appState.resolvedPrimaryProjectID(in: store) == nil {
            appState.setPrimaryProject(firstProjectID)
        }

        if let selectedProjectID = appState.selectedProjectID,
           store.project(with: selectedProjectID) != nil {
            return
        }
        appState.selectedProjectID = firstProjectID
    }
}

private struct AppSidebarSectionRow: View {
    let section: AppSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .frame(width: 18)
                .foregroundStyle(SamouraiSurface.accent)

            Text(section.title)
                .font(.body.weight(.medium))

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? SamouraiSurface.accent.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? SamouraiSurface.accent.opacity(0.18) : Color.clear, lineWidth: 1)
        )
    }
}

private struct ConfigurationWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let primaryProjectName: String?

    @State private var isShowingDeleteConfirmation = false

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

private struct BackupWorkspaceView: View {
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
                            Label("Sauvegarder l'état complet", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onImportBackup) {
                            Label("Restaurer depuis un backup", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(SamouraiLayout.pagePadding)
        }
        .scrollIndicators(.visible)
    }
}

private enum SamouraiBackupContentType {
    static let type = UTType(filenameExtension: "samourai-backup") ?? .json
}

private struct SamouraiBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [SamouraiBackupContentType.type, .json] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
