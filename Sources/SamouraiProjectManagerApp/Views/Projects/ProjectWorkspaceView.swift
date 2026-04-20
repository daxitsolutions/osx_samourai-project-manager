import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store
    @State private var searchText = ""
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var projectEditorContext: ProjectEditorContext?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: EntityCSVDocument?
    @State private var exportFilename = "projects"

    var body: some View {
        @Bindable var appState = appState
        let projects = filteredProjects

        SamouraiWorkspaceSplitView(sidebarMinWidth: 280, sidebarIdealWidth: 320, showsDetail: false) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Portefeuille projets")
                            .font(.title2.weight(.semibold))
                        Text("\(projects.count) / \(store.projects.count) projet(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button("Exporter la vue (\(projects.count))") {
                            prepareExport(projects: projects, filenameSuffix: "vue")
                        }
                        .disabled(projects.isEmpty)

                        Button("Exporter la sélection (\(selectedProjectsForExport.count))") {
                            prepareExport(projects: selectedProjectsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedProjectsForExport.isEmpty)
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }

                    if selectedProjectIDs.isEmpty == false {
                        if selectedProjectIDs.count == 1,
                           let selectedID = selectedProjectIDs.first {
                            Button {
                                projectEditorContext = .edit(selectedID)
                            } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                        }

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedProjectIDs.count > 1 ? "Supprimer (\(selectedProjectIDs.count))" : "Supprimer",
                                systemImage: "trash"
                            )
                        }
                    }

                    Button {
                        projectEditorContext = .create
                    } label: {
                        Label("Nouveau projet", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField("Recherche projet (nom, synthèse, sponsor, pilote, phase)", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                List(projects, selection: $selectedProjectIDs) { project in
                    ProjectListRow(
                        project: project,
                        onNameChange: { updatedName in
                            store.updateProjectQuick(projectID: project.id, name: updatedName, health: project.health)
                        },
                        onHealthChange: { updatedHealth in
                            store.updateProjectQuick(projectID: project.id, name: project.name, health: updatedHealth)
                        }
                    )
                    .tag(project.id)
                    .onTapGesture(count: 2) {
                        projectEditorContext = .edit(project.id)
                    }
                }
                .scrollIndicators(.visible)
            }
            .frame(minWidth: 280, idealWidth: 320)
            .overlay {
                if store.projects.isEmpty {
                    ContentUnavailableView(
                        "Aucun projet",
                        systemImage: "square.grid.2x2",
                        description: Text("Ajoute un projet pour commencer ton pilotage Samourai.")
                    )
                }
            }

        } detail: {
            EmptyView()
        }
        .sheet(item: $projectEditorContext) { context in
            ProjectEditorSheet(project: context.project(in: store))
        }
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert("Supprimer les projets", isPresented: $isShowingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                for projectID in selectedProjectIDs {
                    store.deleteProject(projectID: projectID)
                }
                selectedProjectIDs.removeAll()
                appState.selectedProjectID = nil
            }
            Button("Annuler", role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(
                selectedProjectIDs.count > 1
                ? "Les projets sélectionnés seront supprimés. Les risques sont conservés comme non affectés."
                : "Le projet sélectionné sera supprimé. Les risques seront conservés comme non affectés."
            )
        }
        .onChange(of: selectedProjectIDs) { _, newSelection in
            let singleSelection = newSelection.singleSelection
            appState.selectedProjectID = singleSelection
            if appState.primaryProjectID != singleSelection {
                appState.setPrimaryProject(singleSelection)
            }
        }
        .onChange(of: appState.selectedProjectID) { _, newID in
            guard let newID else { return }
            if selectedProjectIDs != [newID] {
                selectedProjectIDs = [newID]
            }
            if appState.primaryProjectID != newID {
                appState.setPrimaryProject(newID)
            }
        }
        .onChange(of: store.projects.map(\.id)) { _, ids in
            let existing = Set(ids)
            selectedProjectIDs = selectedProjectIDs.intersection(existing)
            appState.selectedProjectID = selectedProjectIDs.singleSelection
        }
    }

    private var filteredProjects: [Project] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return store.projects }
        let terms = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
        return store.projects.filter { project in
            let values = [
                project.name,
                project.summary,
                project.sponsor,
                project.manager,
                project.phase.label,
                project.deliveryMode.label,
                project.health.label
            ]
            let normalized = values.map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            return terms.allSatisfy { term in
                normalized.contains(where: { $0.contains(term) })
            }
        }
    }

    private var selectedProjectsForExport: [Project] {
        filteredProjects.filter { selectedProjectIDs.contains($0.id) }
    }

    private func prepareExport(projects: [Project], filenameSuffix: String) {
        guard projects.isEmpty == false else { return }
        let headers = ["Nom", "Synthese", "Sponsor", "Pilote", "Phase", "Sante", "Livraison", "Cible"]
        let rows = projects.map { project in
            [
                project.name,
                project.summary,
                project.sponsor,
                project.manager,
                project.phase.label,
                project.health.label,
                project.deliveryMode.label,
                project.targetDate.formatted(date: .abbreviated, time: .omitted)
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-projets-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }
}

private enum ProjectEditorContext: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }

    @MainActor
    func project(in store: SamouraiStore) -> Project? {
        switch self {
        case .create: nil
        case .edit(let id): store.project(with: id)
        }
    }
}

private struct ProjectListRow: View {
    let project: Project
    let onNameChange: (String) -> Void
    let onHealthChange: (ProjectHealth) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(
                    "Nom du projet",
                    text: Binding(
                        get: { project.name },
                        set: { onNameChange($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.headline)
                Spacer()
                Picker(
                    "Santé",
                    selection: Binding(
                        get: { project.health },
                        set: { onHealthChange($0) }
                    )
                ) {
                    ForEach(ProjectHealth.allCases) { health in
                        Text(health.label).tag(health)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 18)
            }

            Text(project.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(project.phase.label)
                Spacer()
                Text(project.targetDate.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
