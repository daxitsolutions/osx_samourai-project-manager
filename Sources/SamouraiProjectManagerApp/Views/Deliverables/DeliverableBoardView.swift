import SwiftUI

struct DeliverableBoardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var isShowingDeliverableEditor = false
    @State private var deliverableEditorContext = DeliverableEditorContext()
    @State private var newInScopeItemDraft = ""
    @State private var newOutOfScopeItemDraft = ""
    @State private var acceptanceDraftByDeliverable: [UUID: String] = [:]

    var body: some View {
        Group {
            if let primaryProject = primaryProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: SamouraiLayout.sectionSpacing) {
                        header(primaryProject: primaryProject)
                        perimeterSection(primaryProject: primaryProject)
                        deliverablesWBSSection(primaryProject: primaryProject)
                    }
                    .padding(SamouraiLayout.pagePadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            } else {
                SamouraiEmptyStateCard(
                    title: "Projet principal requis",
                    systemImage: "scope",
                    description: "Définis un Projet Principal dans la barre supérieure pour piloter le périmètre et les livrables."
                )
            }
        }
        .samouraiCanvasBackground()
        .sheet(isPresented: $isShowingDeliverableEditor) {
            if let primaryProject {
                DeliverableScopeEditorSheet(
                    primaryProject: primaryProject,
                    context: deliverableEditorContext,
                    onSave: { payload in
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
        }
    }

    private var primaryProject: Project? {
        guard let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) else { return nil }
        return store.project(with: primaryProjectID)
    }

    @ViewBuilder
    private func header(primaryProject: Project) -> some View {
        SamouraiPageHeader(
            eyebrow: "Scope",
            title: "Livrables & périmètre",
            subtitle: "Tout ce qui aide l’utilisateur à comprendre le scope, la couverture et les changements sans perdre le fil du projet."
        ) {
            Button {
                deliverableEditorContext = DeliverableEditorContext(parentDeliverableID: nil, suggestedPhase: .delivery)
                isShowingDeliverableEditor = true
            } label: {
                Label(localized("Livrable principal"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func perimeterSection(primaryProject: Project) -> some View {
        let inScopeItems = primaryProject.scopeDefinition?.inScopeItems ?? []
        let outOfScopeItems = primaryProject.scopeDefinition?.outOfScopeItems ?? []

        SamouraiSectionCard(
            title: "Périmètre",
            subtitle: "Éléments explicitement inclus et exclus du projet."
        ) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("In scope"))
                        .font(.headline)

                    if inScopeItems.isEmpty {
                        Text(localized("Aucun élément in scope"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inScopeItems, id: \.self) { item in
                            HStack {
                                Text(item)
                                    .font(.callout)
                                Spacer()
                                Button(role: .destructive) {
                                    store.removeInScopeItem(projectID: primaryProject.id, item: item)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        TextField(localized("Ajouter un élément in scope"), text: $newInScopeItemDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                let trimmed = newInScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard trimmed.isEmpty == false else { return }
                                store.addInScopeItem(projectID: primaryProject.id, item: trimmed)
                                newInScopeItemDraft = ""
                            }
                        Button {
                            let trimmed = newInScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmed.isEmpty == false else { return }
                            store.addInScopeItem(projectID: primaryProject.id, item: trimmed)
                            newInScopeItemDraft = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(newInScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("Out of scope"))
                        .font(.headline)

                    if outOfScopeItems.isEmpty {
                        Text(localized("Aucun élément out of scope"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(outOfScopeItems, id: \.self) { item in
                            HStack {
                                Text(item)
                                    .font(.callout)
                                Spacer()
                                Button(role: .destructive) {
                                    store.removeOutOfScopeItem(projectID: primaryProject.id, item: item)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        TextField(localized("Ajouter un élément out of scope"), text: $newOutOfScopeItemDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                let trimmed = newOutOfScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard trimmed.isEmpty == false else { return }
                                store.addOutOfScopeItem(projectID: primaryProject.id, item: trimmed)
                                newOutOfScopeItemDraft = ""
                            }
                        Button {
                            let trimmed = newOutOfScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmed.isEmpty == false else { return }
                            store.addOutOfScopeItem(projectID: primaryProject.id, item: trimmed)
                            newOutOfScopeItemDraft = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(newOutOfScopeItemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func deliverablesWBSSection(primaryProject: Project) -> some View {
        SamouraiSectionCard(
            title: "Structure des livrables",
            subtitle: "Une lecture simple du WBS léger, directement orientée action et validation."
        ) {
            let deliverables = primaryProject.deliverables
            if deliverables.isEmpty {
                SamouraiEmptyStateCard(
                    title: "Aucun livrable",
                    systemImage: "checklist",
                    description: "Crée un livrable principal puis ses sous-livrables par phase."
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
            HStack {
                Text(phase.label)
                    .font(.headline)
                Spacer()
                SamouraiStatusPill(text: "\(mains.count) bloc(s)", tint: SamouraiSurface.accent)
            }

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
        .padding(16)
        .samouraiCardSurface()
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
                        Text(localized("Jalon"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                    }
                    Text(appState.localizedFormat("Owner: %@ • Échéance: %@", deliverable.owner, deliverable.dueDate.formatted(date: .abbreviated, time: .omitted)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(deliverable.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if level == 0 {
                    Button(localized("Sous-livrable")) {
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
        .samouraiCardSurface()
    }

    @ViewBuilder
    private func acceptanceCriteriaSection(projectID: UUID, deliverable: Deliverable) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localized("Critères d'acceptation"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(appState.localizedFormat("%d/%d validés", deliverable.validatedAcceptanceCount, deliverable.acceptanceCriteria.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if deliverable.acceptanceCriteria.isEmpty {
                Text(localized("Aucun critère défini"))
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

                Button(localized("Ajouter")) {
                    let value = (acceptanceDraftByDeliverable[deliverable.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard value.isEmpty == false else { return }
                    store.addAcceptanceCriterion(projectID: projectID, deliverableID: deliverable.id, criterionText: value)
                    acceptanceDraftByDeliverable[deliverable.id] = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }


    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
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
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false
    @State private var titleTouched = false

    private var titleIsEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var titlePlaceholder: String {
        context.parentDeliverableID == nil
            ? localized("Livrable principal")
            : localized("Sous-livrable")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    if let primaryProject {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                            Text(appState.localizedFormat("Projet principal: %@", primaryProject.name))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    formSection(title: localized("Métadonnées")) {
                        VStack(alignment: .leading, spacing: 24) {
                            fieldStack(label: localized("Phase")) {
                                Picker("", selection: $phase) {
                                    ForEach(DeliverablePhase.allCases) { phase in
                                        Text(phase.label).tag(phase)
                                    }
                                }
                                .labelsHidden()
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            fieldStack(label: localized("Owner"), required: true) {
                                TextField(localized("Responsable du livrable"), text: $owner)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minHeight: 44)
                            }

                            fieldStack(label: localized("Échéance")) {
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .frame(minHeight: 44)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    formSection(title: localized("Détails du livrable")) {
                        VStack(alignment: .leading, spacing: 24) {
                            fieldStack(label: titlePlaceholder, required: true) {
                                TextField(titlePlaceholder, text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minHeight: 44)
                                    .overlay(alignment: .trailing) {
                                        if titleTouched && titleIsEmpty {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .padding(.trailing, 6)
                                        }
                                    }
                                    .onSubmit { titleTouched = true }
                                    .onChange(of: title) { _, _ in
                                        if !titleIsEmpty { titleTouched = true }
                                    }
                                if titleTouched && titleIsEmpty {
                                    Label(localized("Ce champ est obligatoire"), systemImage: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            fieldStack(label: localized("Description"), required: true) {
                                TextField(
                                    localized("Précisez les objectifs du livrable..."),
                                    text: $details,
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                            }

                            if context.parentDeliverableID == nil {
                                Toggle(isOn: $isMilestone) {
                                    Text(localized("Traiter ce livrable comme un jalon"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .toggleStyle(.switch)
                                .frame(minHeight: 44)
                            }
                        }
                    }

                    if context.parentDeliverableID == nil {
                        formSection(title: localized("Critères d'acceptation")) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField(
                                    localized("Un critère par ligne"),
                                    text: $acceptanceCriteriaRaw,
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(4...8)
                                Text(localized("Un critère par ligne"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(.background)
            .navigationTitle(context.parentDeliverableID == nil ? localized("Nouveau livrable") : localized("Nouveau sous-livrable"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) { requestDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Créer")) {
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
        .frame(minWidth: 620, minHeight: 600)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
                Button(localized("Enregistrer")) {
                    submit()
                }
            }
            Button(localized("Ignorer les modifications"), role: .destructive) {
                dismiss()
            }
            Button(localized("Continuer l'édition"), role: .cancel) {}
        } message: {
            Text(localized("Les informations déjà saisies peuvent être enregistrées ou abandonnées."))
        }
        .onAppear {
            phase = context.suggestedPhase
            captureInitialSnapshotIfNeeded()
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

    private var snapshot: String {
        [
            title,
            details,
            owner,
            String(dueDate.timeIntervalSinceReferenceDate),
            phase.rawValue,
            isMilestone ? "1" : "0",
            acceptanceCriteriaRaw
        ].joined(separator: "|")
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDismissConfirmation = true
        } else {
            dismiss()
        }
    }

    private func captureInitialSnapshotIfNeeded() {
        if initialSnapshot == nil {
            initialSnapshot = snapshot
        }
    }

    private func submit() {
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

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func fieldStack<Content: View>(label: String, required: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if required {
                    Text("*")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                if let project {
                    Text(appState.localizedFormat("Projet principal: %@", project.name))
                        .foregroundStyle(.secondary)
                }

                Section(localized("Description du changement")) {
                    TextField(localized("Décris précisément l'évolution demandée"), text: $descriptionText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section(localized("Analyse d'impact")) {
                    TextField(localized("Impact Planning"), text: $impactPlanning, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(localized("Impact Ressources"), text: $impactResources, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(localized("Impact Risques"), text: $impactRisks, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(localized("Émetteur")) {
                    TextField(localized("Requested by"), text: $requestedBy)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(localized("Nouvelle Change Request"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) { requestDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Soumettre")) {
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
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand {
            requestDismiss()
        }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button(localized("Enregistrer")) {
                    submit()
                }
            }
            Button(localized("Ignorer les modifications"), role: .destructive) {
                dismiss()
            }
            Button(localized("Continuer l'édition"), role: .cancel) {}
        } message: {
            Text(localized("Les informations déjà saisies peuvent être enregistrées ou abandonnées."))
        }
        .onAppear {
            captureInitialSnapshotIfNeeded()
        }
    }

    private var snapshot: String {
        [
            descriptionText,
            impactPlanning,
            impactResources,
            impactRisks,
            requestedBy
        ].joined(separator: "|")
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDismissConfirmation = true
        } else {
            dismiss()
        }
    }

    private func captureInitialSnapshotIfNeeded() {
        if initialSnapshot == nil {
            initialSnapshot = snapshot
        }
    }

    private func submit() {
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

    @Environment(AppState.self) private var appState

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
