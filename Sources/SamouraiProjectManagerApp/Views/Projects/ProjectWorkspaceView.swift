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
                        Text(localized("Portefeuille projets"))
                            .font(.title2.weight(.semibold))
                        Text(
                            AppLocalizer.localizedFormat(
                                "%d / %d projet(s)",
                                language: appState.interfaceLanguage,
                                projects.count,
                                store.projects.count
                            )
                        )
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button(
                            AppLocalizer.localizedFormat(
                                "Exporter la vue (%d)",
                                language: appState.interfaceLanguage,
                                projects.count
                            )
                        ) {
                            prepareExport(projects: projects, filenameSuffix: "vue")
                        }
                        .disabled(projects.isEmpty)

                        Button(
                            AppLocalizer.localizedFormat(
                                "Exporter la sélection (%d)",
                                language: appState.interfaceLanguage,
                                selectedProjectsForExport.count
                            )
                        ) {
                            prepareExport(projects: selectedProjectsForExport, filenameSuffix: "selection")
                        }
                        .disabled(selectedProjectsForExport.isEmpty)
                    } label: {
                        Label(localized("Exporter"), systemImage: "square.and.arrow.up")
                    }

                    if selectedProjectIDs.isEmpty == false {
                        if selectedProjectIDs.count == 1,
                           let selectedID = selectedProjectIDs.first {
                            Button {
                                projectEditorContext = .edit(selectedID)
                            } label: {
                                Label(localized("Modifier"), systemImage: "pencil")
                            }
                        }

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            if selectedProjectIDs.count > 1 {
                                Label(
                                    AppLocalizer.localizedFormat(
                                        "Supprimer (%d)",
                                        language: appState.interfaceLanguage,
                                        selectedProjectIDs.count
                                    ),
                                    systemImage: "trash"
                                )
                            } else {
                                Label(localized("Supprimer"), systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        projectEditorContext = .create
                    } label: {
                        Label(localized("Nouveau projet"), systemImage: "plus")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 12) {
                    TextField(localized("Recherche projet (nom, synthèse, sponsor, pilote, phase)"), text: $searchText)
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
                        description: Text(localized("Ajoute un projet pour commencer ton pilotage Samourai."))
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
        .alert(localized("Supprimer les projets"), isPresented: $isShowingDeleteConfirmation) {
            Button(localized("Supprimer"), role: .destructive) {
                for projectID in selectedProjectIDs {
                    store.deleteProject(projectID: projectID)
                }
                selectedProjectIDs.removeAll()
                appState.selectedProjectID = nil
            }
            Button(localized("Annuler"), role: .cancel) {
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(selectedProjectIDs.count > 1
                 ? localized("Les projets sélectionnés seront supprimés. Les risques sont conservés comme non affectés.")
                 : localized("Le projet sélectionné sera supprimé. Les risques seront conservés comme non affectés."))
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
                project.phase.label.appLocalized(language: appState.interfaceLanguage),
                project.deliveryMode.label.appLocalized(language: appState.interfaceLanguage),
                project.health.label.appLocalized(language: appState.interfaceLanguage)
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
                project.phase.label.appLocalized(language: appState.interfaceLanguage),
                project.health.label.appLocalized(language: appState.interfaceLanguage),
                project.deliveryMode.label.appLocalized(language: appState.interfaceLanguage),
                project.targetDate.formatted(date: .abbreviated, time: .omitted)
            ]
        }
        let csv = EntityCSVBuilder.build(headers: headers, rows: rows)
        exportDocument = EntityCSVDocument(text: csv)
        exportFilename = "samourai-projets-\(filenameSuffix)-\(Date.now.formatted(.dateTime.year().month().day()))"
        isShowingFileExporter = true
    }

    private func localized(_ key: String) -> String {
        key.appLocalized(language: appState.interfaceLanguage)
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
    @Environment(AppState.self) private var appState

    let project: Project
    let onNameChange: (String) -> Void
    let onHealthChange: (ProjectHealth) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if project.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(project.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            badgeRow

            metadataRows

            progressSection
        }
        .padding(.vertical, 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.health.tintColor)
                .frame(width: 9, height: 9)

            TextField(
                "Nom du projet",
                text: Binding(
                    get: { project.name },
                    set: { onNameChange($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.headline)

            Spacer(minLength: 8)

            Picker(
                "Santé",
                selection: Binding(
                    get: { project.health },
                    set: { onHealthChange($0) }
                )
            ) {
                ForEach(ProjectHealth.allCases) { health in
                    Text(loc(health.label)).tag(health)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 18)
        }
    }

    // MARK: - Badges

    private var badgeRow: some View {
        HStack(spacing: 6) {
            badge(loc(project.health.label), color: project.health.tintColor)
            badge(loc(project.phase.label), color: SamouraiColorTheme.color(.brandBlue))
            badge(loc(project.deliveryMode.label), color: SamouraiColorTheme.color(.brandPurple))
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Metadata

    private var metadataRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                metaItem(icon: "person.crop.circle", value: displayValue(project.sponsor))
                metaItem(icon: "person.badge.shield.checkmark", value: displayValue(project.manager))
            }
            HStack(spacing: 16) {
                metaItem(
                    icon: "calendar",
                    value: "\(project.startDate.formatted(date: .abbreviated, time: .omitted)) → \(project.targetDate.formatted(date: .abbreviated, time: .omitted))"
                )
                metaItem(icon: "clock", value: remainingLabel)
            }
        }
    }

    private func metaItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Progress & counters

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ProgressView(value: project.completionRatio)
                    .tint(project.health.tintColor)
                Text("\(Int((project.completionRatio * 100).rounded()))%")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                counter(
                    icon: "shippingbox",
                    text: AppLocalizer.localizedFormat(
                        "%d/%d livrable(s)",
                        language: appState.interfaceLanguage,
                        project.deliverables.filter(\.isDone).count,
                        project.deliverables.count
                    ),
                    color: SamouraiColorTheme.color(.brandGreen)
                )

                counter(
                    icon: project.criticalRiskCount > 0 ? "exclamationmark.triangle.fill" : "exclamationmark.triangle",
                    text: project.criticalRiskCount > 0
                        ? AppLocalizer.localizedFormat(
                            "%d risque(s) · %d critique(s)",
                            language: appState.interfaceLanguage,
                            project.risks.count,
                            project.criticalRiskCount
                        )
                        : AppLocalizer.localizedFormat(
                            "%d risque(s)",
                            language: appState.interfaceLanguage,
                            project.risks.count
                        ),
                    color: project.criticalRiskCount > 0
                        ? SamouraiColorTheme.color(.dangerRed)
                        : SamouraiColorTheme.color(.textMuted)
                )

                counter(
                    icon: "checklist",
                    text: AppLocalizer.localizedFormat(
                        "Tests %d%%",
                        language: appState.interfaceLanguage,
                        project.testingAverageProgressPercent
                    ),
                    color: project.testingRAGStatus.tintColor
                )
            }
        }
    }

    private func counter(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(color)
    }

    // MARK: - Helpers

    private var remainingLabel: String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: project.targetDate).day ?? 0
        if days < 0 {
            return AppLocalizer.localizedFormat(
                "En retard de %d j",
                language: appState.interfaceLanguage,
                abs(days)
            )
        }
        if days == 0 {
            return loc("Échéance aujourd'hui")
        }
        return AppLocalizer.localizedFormat(
            "%d j restant(s)",
            language: appState.interfaceLanguage,
            days
        )
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? loc("Non défini") : trimmed
    }

    private func loc(_ key: String) -> String {
        key.appLocalized(language: appState.interfaceLanguage)
    }
}
