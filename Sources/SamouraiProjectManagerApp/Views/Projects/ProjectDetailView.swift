import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let projectID: UUID

    @State private var isShowingRiskEditor = false
    @State private var isShowingDeliverableEditor = false
    @State private var activityEditorContext: ProjectActivityEditorContext?
    @State private var activityPendingDeletion: ProjectActivity?
    @State private var planningViewMode: PlanningViewMode = .list
    @State private var planningBaselineLabel = "Fin de Phase"
    @State private var planningValidatedBy = "Chef de Projet"
    @State private var planningFeedbackMessage: String?
    @State private var expandedActivityIDs: Set<UUID> = []
    @State private var resourceFavoriteFilter: ProjectResourceFavoriteFilter = .all

    var body: some View {
        Group {
            if let project = store.project(with: projectID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(project: project)
                        metrics(project: project)
                        projectPlanSection(project: project)
                        testingSection(project: project)
                        resourcesSection(project: project)
                        risksSection(project: project)
                        deliverablesSection(project: project)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            } else {
                ContentUnavailableView(
                    "Projet introuvable",
                    systemImage: "exclamationmark.circle",
                    description: Text("Le projet sélectionné n'existe plus dans le stockage local.")
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { isShowingRiskEditor || isShowingDeliverableEditor || activityEditorContext != nil },
            set: { isPresented in
                if isPresented == false {
                    isShowingRiskEditor = false
                    isShowingDeliverableEditor = false
                    activityEditorContext = nil
                }
            }
        )) {
            if isShowingRiskEditor {
                RiskEditorSheet(projectID: projectID)
            } else if isShowingDeliverableEditor {
                DeliverableEditorSheet(projectID: projectID)
            } else if let context = activityEditorContext {
                ProjectActivityEditorSheet(
                    projectID: projectID,
                    activity: context.activity(in: store),
                    initialParentActivityID: context.initialParentActivityID(),
                    linkedActionIDs: context.linkedActionIDs(in: store),
                    linkedDeliverableIDs: context.linkedDeliverableIDs(in: store)
                )
            }
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
        .alert("Planning Engine", isPresented: Binding(
            get: { planningFeedbackMessage != nil },
            set: { if $0 == false { planningFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(planningFeedbackMessage ?? "")
        }
    }

    private func header(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle.weight(.semibold))
                    Text(project.summary)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(project.health.label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(project.health.tintColor.opacity(0.15), in: Capsule())
            }

            HStack(spacing: 18) {
                Label(project.phase.label, systemImage: "flag.pattern.checkered")
                Label(project.deliveryMode.label, systemImage: "arrow.trianglehead.branch")
                Label("Sponsor: \(project.sponsor)", systemImage: "person.2")
                Label("Pilote: \(project.manager)", systemImage: "person.crop.circle")
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Label("Démarrage \(project.startDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label("Cible \(project.targetDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func metrics(project: Project) -> some View {
        HStack(spacing: 16) {
            detailMetric(title: "Avancement livrables", value: project.completionRatio.formatted(.percent.precision(.fractionLength(0))))
            detailMetric(title: "Risques ouverts", value: "\(project.risks.count)")
            detailMetric(title: "Critiques", value: "\(project.criticalRiskCount)")
            detailMetric(title: "Tests QA", value: "\(project.testingAverageProgressPercent)%")
        }
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func resourcesSection(project: Project) -> some View {
        let assignedResources = store.resources(for: project.id)
        let displayedResources = assignedResources.filter { resource in
            switch resourceFavoriteFilter {
            case .all:
                return true
            case .favoritesOnly:
                return resource.isFavorite(in: project.id)
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ressources affectées")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Favoris", selection: $resourceFavoriteFilter) {
                    ForEach(ProjectResourceFavoriteFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                Button("Gérer les ressources") {
                    appState.selectedSection = .resources
                }
            }

            if assignedResources.isEmpty {
                ContentUnavailableView(
                    "Aucune ressource affectée",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Assigne des ressources à ce projet pour matérialiser la capacité réellement disponible.")
                )
            } else if displayedResources.isEmpty {
                ContentUnavailableView(
                    "Aucune ressource favorite",
                    systemImage: "star.slash",
                    description: Text("Active l'étoile jaune sur les ressources clés pour les retrouver plus vite.")
                )
            } else {
                ForEach(displayedResources) { resource in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            appState.openResource(resource.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(resource.status.tintColor)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(resource.displayName)
                                            .font(.headline)
                                        Image(systemName: resource.isFavorite(in: project.id) ? "star.fill" : "star")
                                            .foregroundStyle(resource.isFavorite(in: project.id) ? .yellow : .secondary)
                                        Spacer()
                                        Text(resource.allocationLabel)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(resource.displayPrimaryRole.isEmpty ? "Rôle non renseigné" : resource.displayPrimaryRole)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 16) {
                                        Text(resource.engagement.label)
                                        Text(resource.status.label)
                                    }
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.toggleFavoriteResource(resourceID: resource.id, in: project.id)
                        } label: {
                            Image(systemName: resource.isFavorite(in: project.id) ? "star.fill" : "star")
                                .foregroundStyle(resource.isFavorite(in: project.id) ? .yellow : .secondary)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func testingSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tests & Contrôle Qualité")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(project.testingRAGStatus.symbol) \(project.testingRAGStatus.label)")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(project.testingRAGStatus.tintColor.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 18) {
                Label("Avancement moyen: \(project.testingAverageProgressPercent)%", systemImage: "chart.line.uptrend.xyaxis")
                Label("Phases bloquées: \(project.blockedTestingPhaseCount)", systemImage: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if store.shouldSuggestGoNoGoDecision(projectID: project.id) {
                HStack {
                    Text("UAT à 100% : proposer automatiquement une décision de lancement.")
                        .font(.callout)
                    Spacer()
                    Button("Créer décision Go / No-Go") {
                        guard let decisionID = store.createGoNoGoDecision(projectID: project.id) else { return }
                        appState.openDecision(decisionID)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("Phase").font(.caption.weight(.semibold))
                        Text("Statut").font(.caption.weight(.semibold))
                        Text("%").font(.caption.weight(.semibold))
                        Text("Fin estimée").font(.caption.weight(.semibold))
                        Text("Fin réelle").font(.caption.weight(.semibold))
                        Text("Owner").font(.caption.weight(.semibold))
                        Text("Notes / Blocages").font(.caption.weight(.semibold))
                        Text("URL externe").font(.caption.weight(.semibold))
                    }

                    ForEach(project.orderedTestingPhases) { phase in
                        GridRow(alignment: .center) {
                            Text(phase.kind.shortLabel)
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: 62, alignment: .leading)

                            Picker(
                                "Statut",
                                selection: Binding(
                                    get: { phase.status },
                                    set: { newStatus in
                                        var updated = phase
                                        updated.status = newStatus
                                        store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                    }
                                )
                            ) {
                                ForEach(ProjectTestingPhaseStatus.allCases) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 155)

                            TextField(
                                "0",
                                value: Binding(
                                    get: { phase.progressPercent },
                                    set: { newProgress in
                                        var updated = phase
                                        updated.progressPercent = min(max(newProgress, 0), 100)
                                        store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                    }
                                ),
                                format: .number
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)

                            optionalDateCell(
                                date: phase.estimatedEndDate,
                                setDate: { newDate in
                                    var updated = phase
                                    updated.estimatedEndDate = newDate
                                    store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                }
                            )

                            optionalDateCell(
                                date: phase.actualEndDate,
                                setDate: { newDate in
                                    var updated = phase
                                    updated.actualEndDate = newDate
                                    store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                }
                            )

                            TextField(
                                "Owner",
                                text: Binding(
                                    get: { phase.owner },
                                    set: { newOwner in
                                        var updated = phase
                                        updated.owner = newOwner
                                        store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)

                            TextField(
                                "Notes / blocages",
                                text: Binding(
                                    get: { phase.notes },
                                    set: { newNotes in
                                        var updated = phase
                                        updated.notes = newNotes
                                        store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                    }
                                ),
                                axis: .vertical
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)

                            TextField(
                                "https://...",
                                text: Binding(
                                    get: { phase.externalURL },
                                    set: { newURL in
                                        var updated = phase
                                        updated.externalURL = newURL
                                        store.replaceProjectTestingPhase(projectID: project.id, phase: updated)
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        }
                    }
                }
                .padding(10)
            }
            .scrollIndicators(.visible)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func optionalDateCell(date: Date?, setDate: @escaping (Date?) -> Void) -> some View {
        HStack(spacing: 6) {
            DatePicker(
                "",
                selection: Binding(
                    get: { date ?? .now },
                    set: { setDate($0) }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(width: 118)

            Button {
                if date == nil {
                    setDate(.now)
                } else {
                    setDate(nil)
                }
            } label: {
                Image(systemName: date == nil ? "plus.circle" : "xmark.circle")
            }
            .buttonStyle(.plain)
            .help(date == nil ? "Renseigner une date" : "Effacer la date")
        }
    }

    private func projectPlanSection(project: Project) -> some View {
        let projectActivities = store.activities(for: project.id)
        let projectActions = store.actions.filter { $0.projectID == project.id }
        let planningVariance = store.planningVarianceReport(projectID: project.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project Plan · Activités")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Vue", selection: $planningViewMode) {
                    ForEach(PlanningViewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Button("Nouvelle activité") {
                    activityEditorContext = .create
                }
            }

            HStack(spacing: 10) {
                TextField("Label baseline planning", text: $planningBaselineLabel)
                    .textFieldStyle(.roundedBorder)
                TextField("Validé par", text: $planningValidatedBy)
                    .textFieldStyle(.roundedBorder)
                Button("Enregistrer baseline planning") {
                    planningFeedbackMessage = store.createPlanningBaseline(
                        projectID: project.id,
                        label: planningBaselineLabel,
                        validatedBy: planningValidatedBy
                    ) ?? "Création baseline impossible (ajoute au moins une activité)."
                }
                .buttonStyle(.bordered)
            }

            if let planningVariance {
                HStack(spacing: 18) {
                    Label("Baseline: \(planningVariance.baselineLabel)", systemImage: "flag.checkered.circle")
                    Label("Retards: \(planningVariance.delayedCount)", systemImage: "exclamationmark.triangle")
                    Label("Avances: \(planningVariance.acceleratedCount)", systemImage: "arrow.down.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if projectActivities.isEmpty {
                ContentUnavailableView(
                    "Aucune activité planifiée",
                    systemImage: "calendar.badge.clock",
                    description: Text("Définis les activités macro pour cadencer le projet et rattacher les actions opérationnelles.")
                )
            } else if planningViewMode == .timeline || planningViewMode == .ganttLite {
                ProjectTimelineView(
                    activities: projectActivities,
                    varianceReport: planningVariance,
                    showGanttGrid: planningViewMode == .ganttLite
                )
            } else {
                let rootActivities = projectActivities.filter { $0.parentActivityID == nil || $0.isMilestone }
                ForEach(rootActivities) { activity in
                    activityRow(
                        activity: activity,
                        allActivities: projectActivities,
                        projectActions: projectActions,
                        depth: 0
                    )
                }
            }
        }
    }

    private func activityRow(
        activity: ProjectActivity,
        allActivities: [ProjectActivity],
        projectActions: [ProjectAction],
        depth: Int
    ) -> AnyView {
        let linkedActions = projectActions.filter { $0.activityID == activity.id }
        let linkedDeliverables = store.linkedDeliverables(for: activity.id)
        let doneCount = linkedActions.filter(\.isDone).count
        let progress = store.activityProgress(activityID: activity.id)
        let childActivities = allActivities.filter { $0.parentActivityID == activity.id && $0.isMilestone == false }
        let isExpanded = expandedActivityIDs.contains(activity.id)
        let levelTitle = activity.hierarchyLevel.label
        let levelColor = activity.hierarchyLevel.tintColor
        let predecessorTitles = allActivities
            .filter { activity.predecessorActivityIDs.contains($0.id) }
            .map(\.displayTitle)

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                TextField(
                    "Titre de l'activité",
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
                .font(.headline)

                Text(levelTitle)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(levelColor.opacity(depth == 0 ? 0.25 : 0.15), in: Capsule())

                if activity.isMilestone {
                    Text("Jalon")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 163 / 255, green: 53 / 255, blue: 238 / 255).opacity(0.2), in: Capsule())
                }

                Button("Associer actions/livrables") {
                    activityEditorContext = .edit(activity.id)
                }
                .buttonStyle(.bordered)

                Button {
                    activityEditorContext = .createChild(parentActivityID: activity.id)
                } label: {
                    Label("Nouvelle activité", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    activityPendingDeletion = activity
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 16) {
                if activity.isMilestone == false {
                    DatePicker(
                        "Début estimé",
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
                }

                DatePicker(
                    activity.isMilestone ? "Date jalon (fin)" : "Fin estimée",
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
            }

            HStack(spacing: 16) {
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
                .toggleStyle(.switch)

                if activity.actualEndDate != nil {
                    DatePicker(
                        "Fin réelle",
                        selection: Binding(
                            get: { activity.actualEndDate ?? .now },
                            set: {
                                store.updateActivityQuick(
                                    activityID: activity.id,
                                    title: activity.title,
                                    estimatedStartDate: activity.estimatedStartDate,
                                    estimatedEndDate: activity.estimatedEndDate,
                                    actualEndDate: $0
                                )
                            }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Avancement macro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        linkedActions.isEmpty
                        ? progress.formatted(.percent.precision(.fractionLength(0)))
                        : "\(doneCount)/\(linkedActions.count) actions · \(progress.formatted(.percent.precision(.fractionLength(0))))"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
            }

            if linkedActions.isEmpty == false {
                Text("Activités rattachées: \(linkedActions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Justification périmètre")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if linkedDeliverables.isEmpty {
                    Text("⚠️ Aucune liaison livrable: activité non justifiée par le scope")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(linkedDeliverables.map(\.title).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if predecessorTitles.isEmpty == false {
                Text("Dépendances: \(predecessorTitles.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                        activityRow(
                            activity: child,
                            allActivities: allActivities,
                            projectActions: projectActions,
                            depth: depth + 1
                        )
                    }
                }
                .padding(.leading, 14)
            }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(levelColor.opacity(depth == 0 ? 0.12 : 0.08))
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(levelColor.opacity(depth == 0 ? 0.95 : 0.75))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        )
    }

    private func risksSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Registre des risques")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Ajouter un risque") {
                    isShowingRiskEditor = true
                }
            }

            if project.sortedRisks.isEmpty {
                ContentUnavailableView(
                    "Aucun risque",
                    systemImage: "checkmark.shield",
                    description: Text("Ajoute les points de tension pour garder une vision réaliste de l'exécution.")
                )
            } else {
                ForEach(project.sortedRisks) { risk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(risk.displayTitle)
                                .font(.headline)
                            Spacer()
                            Text(risk.severity.label)
                                .foregroundStyle(.secondary)
                        }

                        Text("Owner: \(risk.displayOwner.isEmpty ? "-" : risk.displayOwner)")
                            .foregroundStyle(.secondary)

                        Text(risk.displayMitigation)
                            .font(.callout)

                        if let dueDate = risk.dueDate {
                            Text("Action attendue pour le \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func deliverablesSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Livrables")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Ajouter un livrable") {
                    isShowingDeliverableEditor = true
                }
            }

            if project.sortedDeliverables.isEmpty {
                ContentUnavailableView(
                    "Aucun livrable",
                    systemImage: "doc.badge.plus",
                    description: Text("Crée les livrables de contrôle et de delivery pour matérialiser l'avancement.")
                )
            } else {
                ForEach(project.sortedDeliverables) { deliverable in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            store.toggleDeliverable(projectID: project.id, deliverableID: deliverable.id)
                        } label: {
                            Image(systemName: deliverable.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(deliverable.title)
                                    .font(.headline)
                                Spacer()
                                Text(deliverable.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }

                            Text("Owner: \(deliverable.owner)")
                                .foregroundStyle(.secondary)
                            Text(deliverable.details)
                                .font(.callout)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

private enum ProjectResourceFavoriteFilter: String, CaseIterable, Identifiable {
    case all
    case favoritesOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            "Toutes"
        case .favoritesOnly:
            "Favoris"
        }
    }
}

private enum PlanningViewMode: String, CaseIterable, Identifiable {
    case list
    case timeline
    case ganttLite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .list:
            "Liste"
        case .timeline:
            "Timeline"
        case .ganttLite:
            "Gantt Lite"
        }
    }
}

private enum ProjectActivityEditorContext: Identifiable {
    case create
    case createChild(parentActivityID: UUID)
    case edit(UUID)

    var id: String {
        switch self {
        case .create:
            "create-activity"
        case .createChild(let parentID):
            "create-child-activity-\(parentID.uuidString)"
        case .edit(let activityID):
            "edit-activity-\(activityID.uuidString)"
        }
    }

    @MainActor
    func activity(in store: SamouraiStore) -> ProjectActivity? {
        switch self {
        case .create, .createChild:
            nil
        case .edit(let activityID):
            store.activity(with: activityID)
        }
    }

    @MainActor
    func initialParentActivityID() -> UUID? {
        switch self {
        case .createChild(let parentID): parentID
        default: nil
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
