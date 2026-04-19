import SwiftUI

struct DeliverableBoardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var isShowingDeliverableEditor = false
    @State private var deliverableEditorContext = DeliverableEditorContext()
    @State private var inScopeDraft = ""
    @State private var outOfScopeDraft = ""
    @State private var linkedAnnexProjectIDs: Set<UUID> = []
    @State private var acceptanceDraftByDeliverable: [UUID: String] = [:]
    @State private var isShowingChangeRequestEditor = false
    @State private var baselineMilestoneDraft = "Fin de Phase"
    @State private var baselineValidatedByDraft = "Chef de Projet"
    @State private var changeControlFeedbackMessage: String?

    var body: some View {
        Group {
            if let primaryProject = primaryProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(primaryProject: primaryProject)
                        scopeDefinitionSection(primaryProject: primaryProject)
                        deliverablesWBSSection(primaryProject: primaryProject)
                        traceabilitySection(primaryProject: primaryProject)
                        changeControlSection(primaryProject: primaryProject)
                        annexIntegrationSection(primaryProject: primaryProject)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            } else {
                ContentUnavailableView(
                    "Projet principal requis",
                    systemImage: "scope",
                    description: Text("Définis un Projet Principal dans la barre supérieure pour piloter le périmètre et les livrables.")
                )
            }
        }
        .sheet(isPresented: $isShowingDeliverableEditor) {
            DeliverableScopeEditorSheet(
                primaryProject: primaryProject,
                context: deliverableEditorContext,
                onSave: { payload in
                    guard let primaryProject else { return }
                    store.addDeliverable(
                        to: primaryProject.id,
                        title: payload.title,
                        details: payload.details,
                        owner: payload.owner,
                        dueDate: payload.dueDate,
                        phase: payload.phase,
                        parentDeliverableID: payload.parentDeliverableID,
                        isMilestone: payload.isMilestone,
                        acceptanceCriteria: payload.acceptanceCriteria
                    )
                }
            )
        }
        .sheet(isPresented: $isShowingChangeRequestEditor) {
            ScopeChangeRequestEditorSheet(
                project: primaryProject,
                onSubmit: { payload in
                    guard let primaryProject else { return }
                    changeControlFeedbackMessage = store.submitScopeChangeRequest(
                        projectID: primaryProject.id,
                        description: payload.description,
                        impactPlanning: payload.impactPlanning,
                        impactResources: payload.impactResources,
                        impactRisks: payload.impactRisks,
                        requestedBy: payload.requestedBy
                    ) ?? "Création impossible."
                }
            )
        }
        .alert("Change Control", isPresented: Binding(
            get: { changeControlFeedbackMessage != nil },
            set: { if $0 == false { changeControlFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(changeControlFeedbackMessage ?? "")
        }
        .onAppear {
            loadScopeDraftFromProject()
        }
        .onChange(of: primaryProject?.id) { _, _ in
            loadScopeDraftFromProject()
        }
    }

    private var primaryProject: Project? {
        guard let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) else { return nil }
        return store.project(with: primaryProjectID)
    }

    private var annexCandidateProjects: [Project] {
        guard let primaryProject else { return [] }
        return store.projects.filter { $0.id != primaryProject.id }
    }

    @ViewBuilder
    private func header(primaryProject: Project) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deliverables & Scope")
                    .font(.largeTitle.weight(.semibold))
                Text("Projet principal: \(primaryProject.name)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                deliverableEditorContext = DeliverableEditorContext(parentDeliverableID: nil, suggestedPhase: .delivery)
                isShowingDeliverableEditor = true
            } label: {
                Label("Livrable principal", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func scopeDefinitionSection(primaryProject: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1) Définition du périmètre")
                .font(.title2.weight(.semibold))

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In scope")
                        .font(.headline)
                    TextEditor(text: $inScopeDraft)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Une ligne = un élément inclus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Out of scope")
                        .font(.headline)
                    TextEditor(text: $outOfScopeDraft)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Une ligne = un élément explicitement exclu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Projets annexes intégrés")
                    .font(.headline)

                if annexCandidateProjects.isEmpty {
                    Text("Aucun projet annexe disponible")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(annexCandidateProjects) { project in
                        Toggle(
                            project.name,
                            isOn: Binding(
                                get: { linkedAnnexProjectIDs.contains(project.id) },
                                set: { isSelected in
                                    if isSelected {
                                        linkedAnnexProjectIDs.insert(project.id)
                                    } else {
                                        linkedAnnexProjectIDs.remove(project.id)
                                    }
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Button("Enregistrer le périmètre") {
                store.updateProjectScope(
                    projectID: primaryProject.id,
                    inScopeItems: parseLines(inScopeDraft),
                    outOfScopeItems: parseLines(outOfScopeDraft),
                    linkedAnnexProjectIDs: Array(linkedAnnexProjectIDs)
                )
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func deliverablesWBSSection(primaryProject: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2) Structure des livrables (WBS légère)")
                .font(.title2.weight(.semibold))

            let deliverables = primaryProject.deliverables
            if deliverables.isEmpty {
                ContentUnavailableView(
                    "Aucun livrable",
                    systemImage: "checklist",
                    description: Text("Crée un livrable principal puis ses sous-livrables par phase.")
                )
            } else {
                ForEach(DeliverablePhase.allCases) { phase in
                    let phaseDeliverables = deliverables.filter { $0.phase == phase }
                    if phaseDeliverables.isEmpty == false {
                        phaseSection(phase: phase, projectID: primaryProject.id, deliverables: phaseDeliverables)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func phaseSection(phase: DeliverablePhase, projectID: UUID, deliverables: [Deliverable]) -> some View {
        let mains = deliverables
            .filter { $0.parentDeliverableID == nil }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        VStack(alignment: .leading, spacing: 10) {
            Text(phase.label)
                .font(.headline)

            ForEach(mains) { main in
                deliverableCard(projectID: projectID, deliverable: main, level: 0)

                let children = deliverables
                    .filter { $0.parentDeliverableID == main.id }
                    .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                ForEach(children) { child in
                    deliverableCard(projectID: projectID, deliverable: child, level: 1)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func deliverableCard(projectID: UUID, deliverable: Deliverable, level: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle(
                    "Terminé",
                    isOn: Binding(
                        get: { deliverable.isDone },
                        set: { newValue in
                            if newValue != deliverable.isDone {
                                store.toggleDeliverable(projectID: projectID, deliverableID: deliverable.id)
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)

                VStack(alignment: .leading, spacing: 4) {
                    Text(deliverable.title)
                        .font(level == 0 ? .headline : .subheadline.weight(.semibold))
                    if deliverable.isMilestone {
                        Text("Jalon")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                    }
                    Text("Owner: \(deliverable.owner) • Échéance: \(deliverable.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(deliverable.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if level == 0 {
                    Button("Sous-livrable") {
                        deliverableEditorContext = DeliverableEditorContext(parentDeliverableID: deliverable.id, suggestedPhase: deliverable.phase)
                        isShowingDeliverableEditor = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            if level == 0 {
                acceptanceCriteriaSection(projectID: projectID, deliverable: deliverable)
            }
        }
        .padding(10)
        .padding(.leading, CGFloat(level) * 24)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func acceptanceCriteriaSection(projectID: UUID, deliverable: Deliverable) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Critères d'acceptation")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(deliverable.validatedAcceptanceCount)/\(deliverable.acceptanceCriteria.count) validés")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if deliverable.acceptanceCriteria.isEmpty {
                Text("Aucun critère défini")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deliverable.acceptanceCriteria) { criterion in
                    HStack {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { criterion.isValidated },
                                set: { isValidated in
                                    if isValidated != criterion.isValidated {
                                        store.toggleAcceptanceCriterion(projectID: projectID, deliverableID: deliverable.id, criterionID: criterion.id)
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.checkbox)

                        Text(criterion.text)
                            .font(.caption)

                        Spacer()

                        Button(role: .destructive) {
                            store.removeAcceptanceCriterion(projectID: projectID, deliverableID: deliverable.id, criterionID: criterion.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                TextField(
                    "Nouveau critère mesurable",
                    text: Binding(
                        get: { acceptanceDraftByDeliverable[deliverable.id] ?? "" },
                        set: { acceptanceDraftByDeliverable[deliverable.id] = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button("Ajouter") {
                    let value = (acceptanceDraftByDeliverable[deliverable.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard value.isEmpty == false else { return }
                    store.addAcceptanceCriterion(projectID: projectID, deliverableID: deliverable.id, criterionText: value)
                    acceptanceDraftByDeliverable[deliverable.id] = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func annexIntegrationSection(primaryProject: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("4) Intégration des projets annexes")
                .font(.title2.weight(.semibold))

            let integrated = store.annexDeliverablesIntegrated(into: primaryProject.id)
            if integrated.isEmpty {
                Text("Aucun livrable annexe intégré pour l'instant.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(integrated) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.deliverable.title)
                                .font(.headline)
                            Text(entry.projectName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.deliverable.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.deliverable.phase.label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func traceabilitySection(primaryProject: Project) -> some View {
        let coverage = store.scopeCoverageReport(projectID: primaryProject.id)
        let baselineProgress = store.scopeBaselineExecutionProgress(projectID: primaryProject.id)

        VStack(alignment: .leading, spacing: 12) {
            Text("Traçabilité Scope → Plan → Exécution")
                .font(.title2.weight(.semibold))

            HStack(spacing: 14) {
                traceabilityMetric(
                    title: "Couverture du périmètre",
                    value: "\(coverage.coveragePercent)%",
                    detail: "\(coverage.coveredCount)/\(coverage.totalCount) livrables majeurs couverts"
                )
                traceabilityMetric(
                    title: "Avancement baseline",
                    value: baselineProgress.map { "\($0.progressPercent)%" } ?? "N/A",
                    detail: baselineProgress.map { "Baseline \($0.baselineLabel): \($0.acceptedCount)/\($0.totalCount) acceptés" } ?? "Aucune baseline disponible"
                )
            }

            if coverage.entries.isEmpty {
                Text("Aucun livrable majeur à tracer.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coverage.entries) { entry in
                    HStack {
                        Text(entry.isCovered ? "✅" : "⚠️")
                        Text(entry.title)
                            .font(.subheadline.weight(.semibold))
                        if entry.isMilestone {
                            Text("Jalon")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        Text(entry.isMilestone ? "Couvert (jalon)" : "\(entry.linkedActivityCount) activité(s) liée(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func traceabilityMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func changeControlSection(primaryProject: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3) Change Control & Scope Baselining")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("Baseline de référence")
                    .font(.headline)

                HStack {
                    TextField("Jalon (ex: Fin d'Initiation)", text: $baselineMilestoneDraft)
                        .textFieldStyle(.roundedBorder)
                    TextField("Validé par", text: $baselineValidatedByDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Créer baseline") {
                        changeControlFeedbackMessage = store.createScopeBaseline(
                            projectID: primaryProject.id,
                            milestoneLabel: baselineMilestoneDraft,
                            validatedBy: baselineValidatedByDraft
                        ) ?? "Création de baseline impossible."
                    }
                    .buttonStyle(.borderedProminent)
                }

                if primaryProject.scopeBaselines.isEmpty {
                    Text("Aucune baseline validée.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(primaryProject.scopeBaselines.sorted { $0.createdAt > $1.createdAt }) { baseline in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(baseline.milestoneLabel) • \(baseline.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline.weight(.semibold))
                            Text("Validé par: \(baseline.validatedBy) • CR associées: \(baseline.associatedChangeRequestIDs.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("In scope: \(baseline.scopeSnapshot.inScopeItems.count) • Out of scope: \(baseline.scopeSnapshot.outOfScopeItems.count) • Livrables snapshot: \(baseline.deliverableSnapshots.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Demandes de changement")
                        .font(.headline)
                    Spacer()
                    Button("Nouvelle CR") {
                        isShowingChangeRequestEditor = true
                    }
                    .buttonStyle(.bordered)
                }

                if primaryProject.scopeChangeRequests.isEmpty {
                    Text("Aucune demande de changement.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(primaryProject.scopeChangeRequests.sorted { $0.createdAt > $1.createdAt }) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(request.description)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Statut: \(request.status.label) • Créée: \(request.createdAt.formatted(date: .abbreviated, time: .shortened)) • Par: \(request.requestedBy)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let baselineID = request.associatedBaselineID {
                                        Text("Associée baseline: \(baselineID.uuidString.prefix(8))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    if request.status == .proposed {
                                        Button("Reviewed") {
                                            transitionCR(primaryProjectID: primaryProject.id, requestID: request.id, targetStatus: .reviewed)
                                        }
                                        .buttonStyle(.bordered)
                                    } else if request.status == .reviewed {
                                        Button("Approve") {
                                            transitionCR(primaryProjectID: primaryProject.id, requestID: request.id, targetStatus: .approved)
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Reject") {
                                            transitionCR(primaryProjectID: primaryProject.id, requestID: request.id, targetStatus: .rejected)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                impactCard(title: "Planning", value: request.impactPlanning)
                                impactCard(title: "Ressources", value: request.impactResources)
                                impactCard(title: "Risques", value: request.impactRisks)
                            }

                            if request.history.isEmpty == false {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Historique")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(request.history.sorted { $0.changedAt > $1.changedAt }) { history in
                                        Text("\(history.changedAt.formatted(date: .abbreviated, time: .shortened)) • \(history.status.label) • \(history.actor)\(history.note.isEmpty ? "" : " • \(history.note)")")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    private func transitionCR(primaryProjectID: UUID, requestID: UUID, targetStatus: ScopeChangeRequestStatus) {
        changeControlFeedbackMessage = store.transitionScopeChangeRequest(
            projectID: primaryProjectID,
            requestID: requestID,
            targetStatus: targetStatus,
            actor: baselineValidatedByDraft,
            note: "Transition validée dans le module Deliverables & Scope."
        ) ?? "Transition non autorisée."
    }

    @ViewBuilder
    private func impactCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func parseLines(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func loadScopeDraftFromProject() {
        guard let scope = primaryProject?.scopeDefinition else {
            inScopeDraft = ""
            outOfScopeDraft = ""
            linkedAnnexProjectIDs = []
            return
        }

        inScopeDraft = scope.inScopeItems.joined(separator: "\n")
        outOfScopeDraft = scope.outOfScopeItems.joined(separator: "\n")
        linkedAnnexProjectIDs = Set(scope.linkedAnnexProjectIDs)
    }
}

private struct DeliverableEditorContext {
    var parentDeliverableID: UUID?
    var suggestedPhase: DeliverablePhase = .delivery
}

private struct DeliverableScopeEditorPayload {
    let title: String
    let details: String
    let owner: String
    let dueDate: Date
    let phase: DeliverablePhase
    let parentDeliverableID: UUID?
    let isMilestone: Bool
    let acceptanceCriteria: [String]
}

private struct ScopeChangeRequestPayload {
    let description: String
    let impactPlanning: String
    let impactResources: String
    let impactRisks: String
    let requestedBy: String
}

private struct DeliverableScopeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let primaryProject: Project?
    let context: DeliverableEditorContext
    let onSave: (DeliverableScopeEditorPayload) -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var owner = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var phase: DeliverablePhase = .delivery
    @State private var isMilestone = false
    @State private var acceptanceCriteriaRaw = ""

    var body: some View {
        NavigationStack {
            Form {
                if let primaryProject {
                    Text("Projet principal: \(primaryProject.name)")
                        .foregroundStyle(.secondary)
                }

                Picker("Phase", selection: $phase) {
                    ForEach(DeliverablePhase.allCases) { phase in
                        Text(phase.label).tag(phase)
                    }
                }

                TextField(context.parentDeliverableID == nil ? "Livrable principal" : "Sous-livrable", text: $title)
                TextField("Description", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Owner", text: $owner)
                DatePicker("Échéance", selection: $dueDate, displayedComponents: .date)
                if context.parentDeliverableID == nil {
                    Toggle("Traiter ce livrable comme un jalon", isOn: $isMilestone)
                }

                if context.parentDeliverableID == nil {
                    Section("Critères d'acceptation") {
                        TextField("Un critère par ligne", text: $acceptanceCriteriaRaw, axis: .vertical)
                            .lineLimit(4...8)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(context.parentDeliverableID == nil ? "Nouveau livrable" : "Nouveau sous-livrable")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        onSave(
                            DeliverableScopeEditorPayload(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                                owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
                                dueDate: dueDate,
                                phase: phase,
                                parentDeliverableID: context.parentDeliverableID,
                                isMilestone: isMilestone,
                                acceptanceCriteria: parseLines(acceptanceCriteriaRaw)
                            )
                        )
                        dismiss()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 430)
        .onAppear {
            phase = context.suggestedPhase
        }
    }

    private var formIsInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseLines(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

private struct ScopeChangeRequestEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    let onSubmit: (ScopeChangeRequestPayload) -> Void

    @State private var descriptionText = ""
    @State private var impactPlanning = ""
    @State private var impactResources = ""
    @State private var impactRisks = ""
    @State private var requestedBy = "Chef de Projet"

    var body: some View {
        NavigationStack {
            Form {
                if let project {
                    Text("Projet principal: \(project.name)")
                        .foregroundStyle(.secondary)
                }

                Section("Description du changement") {
                    TextField("Décris précisément l'évolution demandée", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Analyse d'impact") {
                    TextField("Impact Planning", text: $impactPlanning, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Impact Ressources", text: $impactResources, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Impact Risques", text: $impactRisks, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Émetteur") {
                    TextField("Requested by", text: $requestedBy)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Nouvelle Change Request")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Soumettre") {
                        onSubmit(
                            ScopeChangeRequestPayload(
                                description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                                impactPlanning: impactPlanning.trimmingCharacters(in: .whitespacesAndNewlines),
                                impactResources: impactResources.trimmingCharacters(in: .whitespacesAndNewlines),
                                impactRisks: impactRisks.trimmingCharacters(in: .whitespacesAndNewlines),
                                requestedBy: requestedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}
