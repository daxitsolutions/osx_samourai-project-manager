import SwiftUI

struct PlanningWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @AppStorage("planning.table.visibleColumns") private var visibleColumnsRawValue = PlanningTableColumn.defaultVisibleRawValue
    @AppStorage("planning.table.columnOrder") private var columnOrderRawValue = PlanningTableColumn.defaultOrderRawValue

    @State private var selectedScenarioIDs: Set<UUID> = []
    @State private var primaryScenarioID: UUID?
    @State private var editorContext: PlanningEditorContext?
    @State private var activityPendingDeletion: ProjectActivity?
    @State private var expandedActivityIDs: Set<UUID> = []
    @State private var viewMode: PlanningViewMode = .tree
    @State private var isShowingTableConfiguration = false

    var body: some View {
        detailPane
        .sheet(isPresented: Binding(
            get: { editorContext != nil },
            set: { if $0 == false { editorContext = nil } }
        )) {
            if let context = editorContext {
                ProjectActivityEditorSheet(
                    projectID: context.projectID,
                    activity: context.activity(in: store),
                    preferredScenarioID: context.preferredScenarioID(in: store),
                    linkedActionIDs: context.linkedActionIDs(in: store),
                    linkedDeliverableIDs: context.linkedDeliverableIDs(in: store)
                )
            }
        }
        .sheet(isPresented: $isShowingTableConfiguration) {
            PlanningTableConfigurationSheet(
                visibleColumns: visibleColumnsBinding,
                orderedColumns: orderedColumnsBinding,
                onClose: { isShowingTableConfiguration = false }
            )
        }
        .alert("Supprimer l'activité", isPresented: Binding(
            get: { activityPendingDeletion != nil },
            set: { if $0 == false { activityPendingDeletion = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let activity = activityPendingDeletion {
                    store.deleteActivity(activityID: activity.id)
                }
                activityPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                activityPendingDeletion = nil
            }
        } message: {
            Text("L'activité sera supprimée et les actions associées resteront disponibles sans rattachement.")
        }
        .onAppear {
            ensureProjectSelection()
            syncScenarioSelection()
        }
        .onChange(of: appState.primaryProjectID) { _, _ in
            syncScenarioSelection()
        }
        .onChange(of: store.projects.map(\.id)) { _, ids in
            if ids.isEmpty {
                appState.setPrimaryProject(nil)
            } else {
                ensureProjectSelection()
            }
            syncScenarioSelection()
        }
        .onChange(of: selectedProject?.orderedPlanningScenarios.map(\.id) ?? []) { _, _ in
            syncScenarioSelection()
        }
    }

    private var selectedProject: Project? {
        guard let selectedProjectID = appState.resolvedPrimaryProjectID(in: store) ?? store.projects.first?.id else { return nil }
        return store.project(with: selectedProjectID)
    }

    private var projectScenarios: [ProjectPlanningScenario] {
        guard let selectedProject else { return [] }
        return store.planningScenarios(for: selectedProject.id)
    }

    private var visibleScenarios: [ProjectPlanningScenario] {
        let visible = projectScenarios.filter { selectedScenarioIDs.contains($0.id) }
        if visible.isEmpty {
            return Array(projectScenarios.prefix(1))
        }
        return visible
    }

    private var primaryScenario: ProjectPlanningScenario? {
        visibleScenarios.first(where: { $0.id == primaryScenarioID }) ?? visibleScenarios.first
    }

    private var visibleColumnsBinding: Binding<Set<PlanningTableColumn>> {
        Binding(
            get: { visibleTableColumns },
            set: { newValue in
                visibleColumnsRawValue = PlanningTableColumn.encodeVisibleColumns(newValue)
            }
        )
    }

    private var orderedColumnsBinding: Binding<[PlanningTableColumn]> {
        Binding(
            get: { orderedTableColumns },
            set: { newValue in
                columnOrderRawValue = PlanningTableColumn.encodeColumnOrder(newValue)
            }
        )
    }

    private var visibleTableColumns: Set<PlanningTableColumn> {
        PlanningTableColumn.decodeVisibleColumns(visibleColumnsRawValue)
    }

    private var orderedTableColumns: [PlanningTableColumn] {
        PlanningTableColumn.decodeColumnOrder(columnOrderRawValue)
    }

    private var activeTableColumns: [PlanningTableColumn] {
        orderedTableColumns.filter { visibleTableColumns.contains($0) }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let project = selectedProject {
            VStack(spacing: 0) {
                header(for: project)

                Divider()

                if visibleScenarios.isEmpty {
                    ContentUnavailableView(
                        "Aucun scénario",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Ajoute un scénario pour commencer à comparer plusieurs hypothèses de planning.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleScenarios.count == 1, let scenario = visibleScenarios.first {
                    scenarioPanel(for: project, scenario: scenario, comparativeMode: false)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(visibleScenarios) { scenario in
                                scenarioPanel(for: project, scenario: scenario, comparativeMode: true)
                                    .frame(width: 640)
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.visible)
                }
            }
        } else {
            ContentUnavailableView(
                "Choisissez un projet",
                systemImage: "target",
                description: Text("Le projet doit être sélectionné dans la liste déroulante en haut avant de consulter le planning.")
            )
        }
    }

    private func header(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planning · \(project.name)")
                        .font(.title2.weight(.semibold))
                    Text(
                        "\(visibleScenarios.count) scénario(s) affiché(s) · cible \(project.targetDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Picker("Vue", selection: $viewMode) {
                    ForEach(PlanningViewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 430)

                if viewMode == .table {
                    Button {
                        isShowingTableConfiguration = true
                    } label: {
                        Label("Configurer la grille", systemImage: "gearshape")
                    }
                    .help("Afficher/masquer et réordonner les colonnes de la table")
                }

                Button {
                    createScenario(for: project)
                } label: {
                    Label("Nouveau scénario", systemImage: "plus.rectangle.on.rectangle")
                }

                Button {
                    duplicatePrimaryScenario(for: project)
                } label: {
                    Label("Dupliquer", systemImage: "doc.on.doc")
                }
                .disabled(primaryScenario == nil)

                Button {
                    guard let scenario = primaryScenario else { return }
                    editorContext = .create(project.id, scenario.id)
                } label: {
                    Label("Nouvelle activité", systemImage: "plus")
                }
                .disabled(primaryScenario == nil)
            }

            scenarioSelector
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var scenarioSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(projectScenarios) { scenario in
                    HStack(spacing: 8) {
                        Button {
                            focusScenario(scenario.id)
                        } label: {
                            Label(
                                scenario.name,
                                systemImage: primaryScenarioID == scenario.id ? "scope" : "square.stack.3d.up"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(primaryScenarioID == scenario.id ? .accentColor : Color.secondary.opacity(0.45))

                        Button {
                            toggleScenarioVisibility(scenario.id)
                        } label: {
                            Image(systemName: selectedScenarioIDs.contains(scenario.id) ? "eye.fill" : "eye.slash")
                        }
                        .buttonStyle(.bordered)
                        .help(selectedScenarioIDs.contains(scenario.id) ? "Masquer ce scénario" : "Afficher ce scénario")
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedScenarioIDs.contains(scenario.id) ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
                    )
                }
            }
        }
        .scrollIndicators(.visible)
    }

    private func scenarioPanel(for project: Project, scenario: ProjectPlanningScenario, comparativeMode: Bool) -> some View {
        let scenarioActivities = store.activities(for: project.id, scenarioID: scenario.id)
        let varianceReport = store.planningVarianceReport(projectID: project.id, scenarioID: scenario.id)

        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.name)
                        .font(comparativeMode ? .title3.weight(.semibold) : .headline)
                    Text("\(scenarioActivities.count) activité(s)")
                        .foregroundStyle(.secondary)
                    if let varianceReport {
                        Text("Baseline: \(varianceReport.baselineLabel) · Retards: \(varianceReport.delayedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if primaryScenarioID == scenario.id {
                    Text("Scénario actif")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                }

                Button {
                    focusScenario(scenario.id)
                } label: {
                    Label("Focaliser", systemImage: "scope")
                }
                .buttonStyle(.bordered)

                Button {
                    editorContext = .create(project.id, scenario.id)
                } label: {
                    Label("Nouvelle activité", systemImage: "plus")
                }
            }
            .padding(16)

            Divider()

            if scenarioActivities.isEmpty {
                ContentUnavailableView(
                    "Scénario vide",
                    systemImage: "calendar.badge.clock",
                    description: Text("Ajoute des activités dans ce scénario pour comparer cette hypothèse aux autres.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewMode == .tree {
                scenarioTreeView(activities: scenarioActivities)
            } else if viewMode == .timeline || viewMode == .ganttLite {
                ProjectPlanningTimelineView(
                    activities: scenarioActivities,
                    varianceReport: varianceReport,
                    showGanttGrid: viewMode == .ganttLite
                )
                .padding(16)
            } else {
                scenarioTableView(project: project, activities: scenarioActivities)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: comparativeMode ? 20 : 0, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay {
            if comparativeMode {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
        }
    }

    private func scenarioTreeView(activities: [ProjectActivity]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rootActivities(in: activities)) { activity in
                    treeActivityCard(activity: activity, allActivities: activities, depth: 0)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.visible)
    }

    private func scenarioTableView(project: Project, activities: [ProjectActivity]) -> some View {
        let rows = activities.sorted { lhs, rhs in
            if lhs.estimatedEndDate == rhs.estimatedEndDate {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.estimatedEndDate > rhs.estimatedEndDate
        }

        return ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(activeTableColumns) { column in
                        Text(column.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: columnWidth(column), alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                    }
                }

                ForEach(rows) { activity in
                    HStack(spacing: 0) {
                        ForEach(activeTableColumns) { column in
                            planningTableCell(
                                column: column,
                                activity: activity,
                                project: project,
                                scenarioActivities: activities
                            )
                            .frame(width: columnWidth(column), alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                    }
                    .background(Color.secondary.opacity(0.03))
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.35)
                    }
                }
            }
        }
        .scrollIndicators(.visible)
        .padding(16)
    }

    @ViewBuilder
    private func planningTableCell(
        column: PlanningTableColumn,
        activity: ProjectActivity,
        project: Project,
        scenarioActivities: [ProjectActivity]
    ) -> some View {
        switch column {
        case .title:
            TextField(
                "Titre",
                text: Binding(
                    get: { activity.title },
                    set: {
                        store.updateActivityQuick(
                            activityID: activity.id,
                            title: $0,
                            estimatedStartDate: activity.estimatedStartDate,
                            estimatedEndDate: activity.estimatedEndDate,
                            actualEndDate: activity.actualEndDate
                        )
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

        case .type:
            Picker(
                "Type",
                selection: Binding(
                    get: { activity.hierarchyLevel },
                    set: {
                        store.updateActivityQuick(
                            activityID: activity.id,
                            title: activity.title,
                            estimatedStartDate: activity.estimatedStartDate,
                            estimatedEndDate: activity.estimatedEndDate,
                            actualEndDate: activity.actualEndDate,
                            hierarchyLevel: $0
                        )
                    }
                )
            ) {
                ForEach(ActivityHierarchyLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

        case .parent:
            Picker(
                "Parent",
                selection: Binding(
                    get: { activity.parentActivityID },
                    set: { setParent(for: activity, parentID: $0) }
                )
            ) {
                Text("Aucun").tag(Optional<UUID>.none)
                ForEach(scenarioActivities.filter {
                    $0.id != activity.id && $0.hierarchyLevel.sortRank < activity.hierarchyLevel.sortRank
                }) { candidate in
                    Text(candidate.displayTitle).tag(Optional(candidate.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

        case .startDate:
            if activity.isMilestone {
                Text("-")
                    .foregroundStyle(.secondary)
            } else {
                DatePicker(
                    "Début",
                    selection: Binding(
                        get: { activity.estimatedStartDate },
                        set: {
                            store.updateActivityQuick(
                                activityID: activity.id,
                                title: activity.title,
                                estimatedStartDate: $0,
                                estimatedEndDate: activity.estimatedEndDate,
                                actualEndDate: activity.actualEndDate
                            )
                        }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            }

        case .endDate:
            DatePicker(
                "Fin",
                selection: Binding(
                    get: { activity.estimatedEndDate },
                    set: {
                        store.updateActivityQuick(
                            activityID: activity.id,
                            title: activity.title,
                            estimatedStartDate: activity.estimatedStartDate,
                            estimatedEndDate: $0,
                            actualEndDate: activity.actualEndDate
                        )
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()

        case .milestone:
            Toggle(
                "Jalon",
                isOn: Binding(
                    get: { activity.isMilestone },
                    set: {
                        store.updateActivityQuick(
                            activityID: activity.id,
                            title: activity.title,
                            estimatedStartDate: activity.estimatedStartDate,
                            estimatedEndDate: activity.estimatedEndDate,
                            actualEndDate: activity.actualEndDate,
                            isMilestone: $0
                        )
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)

        case .completed:
            Toggle(
                "Clôturée",
                isOn: Binding(
                    get: { activity.actualEndDate != nil },
                    set: { isClosed in
                        store.updateActivityQuick(
                            activityID: activity.id,
                            title: activity.title,
                            estimatedStartDate: activity.estimatedStartDate,
                            estimatedEndDate: activity.estimatedEndDate,
                            actualEndDate: isClosed ? (activity.actualEndDate ?? .now) : nil
                        )
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)

        case .dependencies:
            if activity.predecessorActivityIDs.isEmpty {
                Text("")
            } else {
                Text("\(activity.predecessorActivityIDs.count)")
            }

        case .edit:
            Button("Ouvrir") {
                editorContext = .edit(project.id, activity.id)
            }
            .buttonStyle(.link)
        }
    }

    private func columnWidth(_ column: PlanningTableColumn) -> CGFloat {
        switch column {
        case .title:
            return 320
        case .type:
            return 260
        case .parent:
            return 240
        case .startDate:
            return 130
        case .endDate:
            return 130
        case .milestone:
            return 84
        case .completed:
            return 88
        case .dependencies:
            return 108
        case .edit:
            return 80
        }
    }

    private func setParent(for activity: ProjectActivity, parentID: UUID?) {
        let linkedActionIDs = store.actions
            .filter { $0.activityID == activity.id && $0.projectID == activity.projectID }
            .map(\.id)

        store.updateActivity(
            activityID: activity.id,
            title: activity.title,
            estimatedStartDate: activity.estimatedStartDate,
            estimatedEndDate: activity.estimatedEndDate,
            actualEndDate: activity.actualEndDate,
            linkedActionIDs: linkedActionIDs,
            predecessorActivityIDs: activity.predecessorActivityIDs,
            isMilestone: activity.isMilestone,
            hierarchyLevel: activity.hierarchyLevel,
            parentActivityID: parentID,
            linkedDeliverableIDs: activity.linkedDeliverableIDs
        )
    }

    private func treeActivityCard(activity: ProjectActivity, allActivities: [ProjectActivity], depth: Int) -> AnyView {
        let childActivities = allActivities
            .filter { $0.parentActivityID == activity.id && $0.isMilestone == false }
            .sorted { $0.estimatedStartDate < $1.estimatedStartDate }

        let isExpanded = expandedActivityIDs.contains(activity.id)
        let levelColor = activity.hierarchyLevel.tintColor

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.displayTitle)
                            .font(.headline)
                        HStack(spacing: 10) {
                            Text(activity.hierarchyLevel.label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(levelColor.opacity(0.2), in: Capsule())

                            if activity.isMilestone {
                                Text("Jalon")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 163 / 255, green: 53 / 255, blue: 238 / 255).opacity(0.2), in: Capsule())
                            }
                        }
                    }

                    Spacer()

                    Button("Éditer") {
                        editorContext = .edit(activity.projectID, activity.id)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        activityPendingDeletion = activity
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 18) {
                    Label("Début: \(activity.estimatedStartDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    Label("Fin: \(activity.estimatedEndDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
                    Label(activity.actualEndDate == nil ? "Ouverte" : "Clôturée", systemImage: activity.actualEndDate == nil ? "clock" : "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if childActivities.isEmpty == false {
                    Button(isExpanded ? "- masquer les activités enfants" : "+ voir les activités enfants") {
                        if isExpanded {
                            expandedActivityIDs.remove(activity.id)
                        } else {
                            expandedActivityIDs.insert(activity.id)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                if isExpanded {
                    VStack(spacing: 10) {
                        ForEach(childActivities) { child in
                            treeActivityCard(activity: child, allActivities: allActivities, depth: depth + 1)
                        }
                    }
                    .padding(.leading, 14)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(levelColor.opacity(0.08))
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(levelColor.opacity(0.95))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        )
    }

    private func rootActivities(in activities: [ProjectActivity]) -> [ProjectActivity] {
        activities
            .filter { $0.parentActivityID == nil || $0.isMilestone }
            .sorted { $0.estimatedStartDate < $1.estimatedStartDate }
    }

    private func ensureProjectSelection() {
        guard let firstProjectID = store.projects.first?.id else { return }
        let resolvedProjectID = appState.resolvedPrimaryProjectID(in: store) ?? firstProjectID
        if appState.primaryProjectID != resolvedProjectID {
            appState.setPrimaryProject(resolvedProjectID)
        } else if appState.selectedProjectID != resolvedProjectID {
            appState.selectedProjectID = resolvedProjectID
        }
    }

    private func syncScenarioSelection() {
        guard let project = selectedProject else {
            selectedScenarioIDs = []
            primaryScenarioID = nil
            return
        }

        let scenarios = project.orderedPlanningScenarios
        let validIDs = Set(scenarios.map(\.id))

        selectedScenarioIDs = selectedScenarioIDs.intersection(validIDs)
        if selectedScenarioIDs.isEmpty, let defaultScenarioID = scenarios.first?.id {
            selectedScenarioIDs = [defaultScenarioID]
        }

        if let primaryScenarioID, selectedScenarioIDs.contains(primaryScenarioID) {
            return
        }
        primaryScenarioID = scenarios.first(where: { selectedScenarioIDs.contains($0.id) })?.id
    }

    private func focusScenario(_ scenarioID: UUID) {
        selectedScenarioIDs.insert(scenarioID)
        primaryScenarioID = scenarioID
    }

    private func toggleScenarioVisibility(_ scenarioID: UUID) {
        if selectedScenarioIDs.contains(scenarioID) {
            guard selectedScenarioIDs.count > 1 else {
                primaryScenarioID = scenarioID
                return
            }
            selectedScenarioIDs.remove(scenarioID)
            if primaryScenarioID == scenarioID {
                primaryScenarioID = projectScenarios.first(where: { selectedScenarioIDs.contains($0.id) })?.id
            }
        } else {
            selectedScenarioIDs.insert(scenarioID)
            primaryScenarioID = scenarioID
        }
    }

    private func createScenario(for project: Project) {
        let newName = "Scénario \(project.orderedPlanningScenarios.count + 1)"
        guard let newScenarioID = store.addPlanningScenario(projectID: project.id, name: newName) else { return }
        selectedScenarioIDs.insert(newScenarioID)
        primaryScenarioID = newScenarioID
    }

    private func duplicatePrimaryScenario(for project: Project) {
        guard let primaryScenario else { return }
        guard let duplicatedScenarioID = store.duplicatePlanningScenario(
            projectID: project.id,
            sourceScenarioID: primaryScenario.id,
            name: "Copie de \(primaryScenario.name)"
        ) else {
            return
        }

        selectedScenarioIDs.insert(duplicatedScenarioID)
        primaryScenarioID = duplicatedScenarioID
    }
}

private enum PlanningTableColumn: String, CaseIterable, Identifiable, Hashable {
    case title
    case type
    case parent
    case startDate
    case endDate
    case milestone
    case completed
    case dependencies
    case edit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title:
            "Titre"
        case .type:
            "Type"
        case .parent:
            "Parent"
        case .startDate:
            "Début"
        case .endDate:
            "Fin"
        case .milestone:
            "Jalon"
        case .completed:
            "Clôturée"
        case .dependencies:
            "Dépendances"
        case .edit:
            "Éditer"
        }
    }

    static let defaultVisibleColumns: Set<PlanningTableColumn> = Set(allCases)
    static let defaultVisibleRawValue = encodeVisibleColumns(defaultVisibleColumns)
    static let defaultOrderRawValue = encodeColumnOrder(allCases)

    static func decodeVisibleColumns(_ rawValue: String) -> Set<PlanningTableColumn> {
        let tokens = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let columns = Set(tokens.compactMap(PlanningTableColumn.init(rawValue:)))
        return columns.isEmpty ? defaultVisibleColumns : columns
    }

    static func encodeVisibleColumns(_ columns: Set<PlanningTableColumn>) -> String {
        let normalized = allCases.filter { columns.contains($0) }
        return normalized.map(\.rawValue).joined(separator: ",")
    }

    static func decodeColumnOrder(_ rawValue: String) -> [PlanningTableColumn] {
        let tokens = rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let decoded = tokens.compactMap(PlanningTableColumn.init(rawValue:))
        let deduped = allCases.filter { decoded.contains($0) }
        let missing = allCases.filter { deduped.contains($0) == false }
        let normalized = deduped + missing
        return normalized.isEmpty ? allCases : normalized
    }

    static func encodeColumnOrder(_ columns: [PlanningTableColumn]) -> String {
        let deduped = allCases.filter { columns.contains($0) }
        return deduped.map(\.rawValue).joined(separator: ",")
    }
}

private struct PlanningTableConfigurationSheet: View {
    @Binding var visibleColumns: Set<PlanningTableColumn>
    @Binding var orderedColumns: [PlanningTableColumn]
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Visibilité des colonnes") {
                    ForEach(orderedColumns) { column in
                        Toggle(
                            column.label,
                            isOn: Binding(
                                get: { visibleColumns.contains(column) },
                                set: { isVisible in
                                    if isVisible {
                                        visibleColumns.insert(column)
                                    } else {
                                        visibleColumns.remove(column)
                                        if visibleColumns.isEmpty {
                                            visibleColumns = PlanningTableColumn.defaultVisibleColumns
                                        }
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Ordre des colonnes (glisser-déposer)") {
                    List {
                        ForEach(orderedColumns) { column in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                Text(column.label)
                                Spacer()
                                if visibleColumns.contains(column) == false {
                                    Text("Masquée")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onMove { source, destination in
                            orderedColumns.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .frame(minHeight: 220)
                }
            }
            .navigationTitle("Configuration de la grille")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { onClose() }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Réinitialiser") {
                        visibleColumns = PlanningTableColumn.defaultVisibleColumns
                        orderedColumns = PlanningTableColumn.allCases
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }
}

private enum PlanningViewMode: String, CaseIterable, Identifiable {
    case tree
    case table
    case timeline
    case ganttLite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tree:
            "Arborescence"
        case .table:
            "Tableau"
        case .timeline:
            "Timeline"
        case .ganttLite:
            "Gantt Lite"
        }
    }
}

private struct ProjectPlanningTimelineView: View {
    let activities: [ProjectActivity]
    let varianceReport: ProjectPlanningVarianceReport?
    let showGanttGrid: Bool

    var body: some View {
        let sortedActivities = activities.sorted { $0.estimatedStartDate < $1.estimatedStartDate }
        let minDate = sortedActivities.map(\.estimatedStartDate).min() ?? .now
        let maxDate = sortedActivities.map(\.estimatedEndDate).max() ?? .now
        let totalInterval = max(maxDate.timeIntervalSince(minDate), 1)

        VStack(alignment: .leading, spacing: 8) {
            Text(showGanttGrid ? "Vue Gantt Lite" : "Vue Timeline")
                .font(.headline)

            ForEach(sortedActivities) { activity in
                let startRatio = max(0, min(1, activity.estimatedStartDate.timeIntervalSince(minDate) / totalInterval))
                let endRatio = max(0, min(1, activity.estimatedEndDate.timeIntervalSince(minDate) / totalInterval))
                let widthRatio = max(endRatio - startRatio, 0.015)
                let variance = varianceReport?.activityVariances.first(where: { $0.activityID == activity.id })?.varianceDays ?? 0

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activity.displayTitle)
                            .font(.subheadline.weight(.semibold))
                        if activity.isMilestone {
                            Text("Jalon")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                        }
                        Spacer()
                        Text("Variance: \(variance == 0 ? "0j" : "\(variance > 0 ? "+" : "")\(variance)j")")
                            .font(.caption)
                            .foregroundStyle(variance > 0 ? .orange : (variance < 0 ? .green : .secondary))
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 14)

                            if showGanttGrid {
                                HStack(spacing: 0) {
                                    ForEach(0..<10, id: \.self) { _ in
                                        Rectangle()
                                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                    }
                                }
                                .frame(height: 14)
                            }

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(activity.isMilestone ? Color.purple.opacity(0.8) : Color.accentColor.opacity(0.85))
                                .frame(width: proxy.size.width * widthRatio, height: 14)
                                .offset(x: proxy.size.width * startRatio)
                        }
                    }
                    .frame(height: 14)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            }
        }
    }
}

private enum PlanningEditorContext: Identifiable {
    case create(UUID, UUID)
    case edit(UUID, UUID)

    var id: String {
        switch self {
        case .create(let projectID, let scenarioID):
            "planning-create-\(projectID.uuidString)-\(scenarioID.uuidString)"
        case .edit(let projectID, let activityID):
            "planning-edit-\(projectID.uuidString)-\(activityID.uuidString)"
        }
    }

    var projectID: UUID {
        switch self {
        case .create(let projectID, _), .edit(let projectID, _):
            return projectID
        }
    }

    @MainActor
    func activity(in store: SamouraiStore) -> ProjectActivity? {
        switch self {
        case .create:
            return nil
        case .edit(_, let activityID):
            return store.activity(with: activityID)
        }
    }

    @MainActor
    func preferredScenarioID(in store: SamouraiStore) -> UUID? {
        switch self {
        case .create(_, let scenarioID):
            return scenarioID
        case .edit:
            return activity(in: store)?.scenarioID
        }
    }

    @MainActor
    func linkedActionIDs(in store: SamouraiStore) -> [UUID] {
        guard let activity = activity(in: store) else { return [] }
        return store.actions
            .filter { $0.activityID == activity.id && $0.projectID == activity.projectID }
            .map(\.id)
    }

    @MainActor
    func linkedDeliverableIDs(in store: SamouraiStore) -> [UUID] {
        guard let activity = activity(in: store) else { return [] }
        return activity.linkedDeliverableIDs
    }
}

private extension ProjectActivity {
    var parentSortKey: String {
        parentActivityID?.uuidString ?? ""
    }

    var hierarchyRankSortKey: Int {
        hierarchyLevel.sortRank
    }

    var milestoneSortKey: Int {
        isMilestone ? 1 : 0
    }

    var completedSortKey: Int {
        actualEndDate == nil ? 0 : 1
    }

    var dependencyCount: Int {
        predecessorActivityIDs.count
    }
}
