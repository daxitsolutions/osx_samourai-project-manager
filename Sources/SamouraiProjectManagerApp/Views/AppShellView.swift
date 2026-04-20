import SwiftUI
import UniformTypeIdentifiers

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
            selectedSectionView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .samouraiCanvasBackground()
        }
        .navigationSplitViewStyle(.balanced)
        .samouraiCanvasBackground()
        .inspector(isPresented: Binding(
            get: { appState.isShowingProjectEditor },
            set: { appState.isShowingProjectEditor = $0 }
        )) {
            ProjectEditorSheet()
        }
        .inspectorColumnWidth(min: 420, ideal: 560, max: 760)
        .dynamicWindowSizingForInspector(
            isPresented: appState.isShowingProjectEditor,
            preferredInspectorWidth: 560
        )
        .task {
            await store.loadIfNeeded()
            ensureDefaultProjectSelection()
        }
        .onChange(of: store.projects.map(\.id)) { _, _ in
            ensureDefaultProjectSelection()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                projectScopePicker
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(currentSection.title)
                        .font(.headline)
                    Text(currentSection.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

    private var sidebarView: some View {
        List {
            Section {
                AppSidebarProjectScopeCard(
                    primaryProjectName: primaryProjectName,
                    projectCount: store.projects.count,
                    onCreateProject: {
                        appState.selectedSection = .projects
                        appState.isShowingProjectEditor = true
                    }
                )
                .listRowInsets(.init(top: 10, leading: 12, bottom: 12, trailing: 12))
                .listRowBackground(Color.clear)
            }

            ForEach(AppSectionGroup.allCases) { group in
                Section(group.title) {
                    ForEach(group.sections) { section in
                        sidebarButton(for: section)
                    }
                }
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
        case .planning:
            PlanningWorkspaceView()
        case .reporting:
            ReportingWorkspaceView()
        case .projects:
            ProjectWorkspaceView()
        case .resources:
            ResourceWorkspaceView()
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
        }
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

private struct AppSidebarProjectScopeCard: View {
    let primaryProjectName: String?
    let projectCount: Int
    let onCreateProject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Contexte actif", systemImage: "scope")
                    .font(.headline)
                Spacer()
                SamouraiStatusPill(
                    text: projectCount == 0 ? "Setup" : "Actif",
                    tint: projectCount == 0 ? SamouraiColorTheme.color(.warnYellow) : SamouraiSurface.accent
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryProjectName ?? "Projet principal non défini")
                    .font(.subheadline.weight(.semibold))
                Text(projectCount == 0 ? "Aucun projet disponible" : "\(projectCount) projet(s) chargé(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onCreateProject) {
                Label("Créer un projet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .samouraiCardSurface()
    }
}

private struct AppSidebarSectionRow: View {
    let section: AppSection
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: section.systemImage)
                .frame(width: 18)
                .foregroundStyle(SamouraiSurface.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary)
                Text(section.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
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
