import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var backupDocument: SamouraiBackupDocument?
    @State private var backupFilename = "samourai-backup"
    @State private var backupFeedbackMessage: String?
    @State private var hasAttemptedInitialFocus = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(AppSection.allCases, selection: $appState.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch appState.selectedSection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .reporting:
                    ReportingWorkspaceView()
                case .projects:
                    ProjectWorkspaceView()
                case .resources:
                    ResourceWorkspaceView()
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $appState.isShowingProjectEditor) {
            ProjectEditorSheet()
        }
        .task {
            await store.loadIfNeeded()
            if appState.resolvedPrimaryProjectID(in: store) == nil, appState.primaryProjectID != nil {
                appState.setPrimaryProject(nil)
            }
        }
        .onChange(of: store.projects.map(\.id)) { _, _ in
            if appState.resolvedPrimaryProjectID(in: store) == nil, appState.primaryProjectID != nil {
                appState.setPrimaryProject(nil)
            }
        }
        .onAppear {
            guard !hasAttemptedInitialFocus else { return }
            hasAttemptedInitialFocus = true
            requestWindowFocus()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Label("Projet", systemImage: "target")
                        .foregroundStyle(.secondary)

                    Picker(
                        "Projet principal",
                        selection: Binding(
                            get: { appState.resolvedPrimaryProjectID(in: store) },
                            set: { appState.setPrimaryProject($0) }
                        )
                    ) {
                        Text("Aucun (manuel)").tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 220)
                }
            }

            ToolbarItem(placement: .automatic) {
                Menu("Sauvegardes") {
                    Button("Sauvegarder l'état complet") {
                        do {
                            let data = try store.exportBackupData()
                            backupDocument = SamouraiBackupDocument(data: data)
                            backupFilename = "samourai-backup-\(Date.now.formatted(.dateTime.year().month().day()))"
                            isShowingBackupExporter = true
                        } catch {
                            backupFeedbackMessage = error.localizedDescription
                        }
                    }

                    Button("Restaurer depuis un backup") {
                        isShowingBackupImporter = true
                    }
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

    private func requestWindowFocus() {
        // Retry a few times because the first window may not be fully key-able on first callback.
        bringMainWindowToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            bringMainWindowToFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            bringMainWindowToFront()
        }
    }

    private func bringMainWindowToFront() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let window = NSApplication.shared.windows.first { $0.isVisible } ?? NSApplication.shared.windows.first
        window?.makeKeyAndOrderFront(nil)
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
