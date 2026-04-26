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
    @Environment(RESTAPIService.self) private var restAPIService

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
            synchronizeRESTAPIService()
        }
        .onChange(of: store.projects.map(\.id)) { _, _ in
            ensureDefaultProjectSelection()
        }
        .onChange(of: appState.isRESTAPIEnabled) { _, _ in
            synchronizeRESTAPIService()
        }
        .onChange(of: appState.restAPIPort) { _, _ in
            synchronizeRESTAPIService()
        }
        .toolbar {
            if currentSection.showsProjectPicker {
                ToolbarItem(placement: .navigation) {
                    projectScopePicker
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(currentSection.localizedTitle(language: appState.interfaceLanguage))
                        .font(.headline)
                    Text(localizedToolbarSubtitle)
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
                backupFeedbackMessage = localized("Sauvegarde exportée avec succès.")
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
        .alert(localized("Action impossible"), isPresented: Binding(
            get: { store.lastErrorMessage != nil },
            set: { if $0 == false { store.lastErrorMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(store.lastErrorMessage ?? localized("Une erreur inconnue s'est produite."))
        }
        .alert(localized("Sauvegarde / restauration"), isPresented: Binding(
            get: { backupFeedbackMessage != nil },
            set: { if $0 == false { backupFeedbackMessage = nil } }
        )) {
            Button(localized("OK"), role: .cancel) {}
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
            Section(AppSectionGroup.portfolio.localizedTitle(language: appState.interfaceLanguage)) {
                sidebarButton(for: .projects)
            }

            Section(AppSectionGroup.project.localizedTitle(language: appState.interfaceLanguage)) {
                if let primaryProjectName {
                    Text(primaryProjectName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                } else {
                    Text(localized("Choisir un projet en haut de page"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                }

                ForEach(projectSections) { section in
                    sidebarButton(for: section)
                }
            }

            Section(AppSectionGroup.directory.localizedTitle(language: appState.interfaceLanguage)) {
                sidebarButton(for: .resourceDirectory)
            }

            Section(AppSectionGroup.configuration.localizedTitle(language: appState.interfaceLanguage)) {
                sidebarButton(for: .configuration)
            }

            Section(AppSectionGroup.backups.localizedTitle(language: appState.interfaceLanguage)) {
                sidebarButton(for: .backups)
            }
        }
        .navigationTitle(localized("Samourai"))
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

    private func synchronizeRESTAPIService() {
        guard store.hasLoaded else { return }
        if appState.isRESTAPIEnabled == false {
            restAPIService.stop()
            return
        }

        guard restAPIService.isRunning == false || restAPIService.activePort != appState.restAPIPort else {
            return
        }

        do {
            try restAPIService.restart(port: appState.restAPIPort, store: store)
        } catch {
            appState.isRESTAPIEnabled = false
            restAPIService.reportConfigurationError(error.localizedDescription)
        }
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

    private var localizedToolbarSubtitle: String {
        if currentSection.showsProjectPicker, let primaryProjectName {
            return primaryProjectName
        }
        return currentSection.localizedSummary(language: appState.interfaceLanguage)
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
            Label(localized("Projet"), systemImage: "target")
                .foregroundStyle(.secondary)

            if store.projects.isEmpty {
                Text(localized("Aucun projet"))
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    localized("Projet principal"),
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
            backupFilename = localized("samourai-backup") + "-\(Date.now.formatted(.dateTime.year().month().day()))"
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
            let restorationSummary = AppLocalizer.localizedFormat(
                "Restauration terminée : %@",
                language: appState.interfaceLanguage,
                restoreResult.summary
            )
            let restorationMetadata = AppLocalizer.localizedFormat(
                "Backup exporté le %@ depuis la version %@.",
                language: appState.interfaceLanguage,
                restoreResult.exportedAt.formatted(date: .abbreviated, time: .shortened),
                restoreResult.sourceAppVersion
            )
            backupFeedbackMessage = "\(restorationSummary)\n\(restorationMetadata)"
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

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct AppSidebarSectionRow: View {
    @Environment(AppState.self) private var appState

    let section: AppSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .frame(width: 18)
                .foregroundStyle(SamouraiSurface.accent)

            Text(section.localizedTitle(language: appState.interfaceLanguage))
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
