import SwiftUI

struct ResourceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let resource: Resource?

    @State private var nom: String
    @State private var parentDescription: String
    @State private var primaryResourceRole: String
    @State private var resourceRoles: String
    @State private var organizationalResource: String
    @State private var competence1: String
    @State private var resourceCalendar: String
    @State private var resourceStartDate: Date?
    @State private var resourceFinishDate: Date?
    @State private var responsableOperationnel: String
    @State private var responsableInterne: String
    @State private var localisation: String
    @State private var typeDeRessource: String
    @State private var journeesTempsPartiel: String
    @State private var email: String
    @State private var phone: String
    @State private var assignedProjectIDs: Set<UUID>
    @State private var memoFunctionName: String
    @State private var memoFunction: String
    @State private var memoHolder: String
    @State private var memoReportsTo: String
    @State private var memoMainMission: String
    @State private var memoResponsibleFor: String
    @State private var memoDeliverables: String
    @State private var memoWhatIDo: String
    @State private var memoWhatIDoButShouldNot: String
    @State private var memoWhatIDoNotDo: String
    @State private var memoNeeds: String
    @State private var memoProvidesTo: String
    @State private var memoMainTools: String
    @State private var memoCurrentProjectOccupancyRate: String
    @State private var memoUpdatedAt: Date?
    @State private var notes: String
    @State private var templateResourceID: UUID?
    @State private var didApplyPrimaryProjectDefault = false
    @State private var initialSnapshot: String?
    @State private var isShowingDismissConfirmation = false
    @State private var nomTouched = false

    init(resource: Resource?) {
        self.resource = resource
        _nom = State(initialValue: resource?.nom ?? resource?.fullName ?? "")
        _parentDescription = State(initialValue: resource?.parentDescription ?? resource?.department ?? "")
        _primaryResourceRole = State(initialValue: resource?.primaryResourceRole ?? resource?.jobTitle ?? "")
        _resourceRoles = State(initialValue: resource?.resourceRoles ?? "")
        _organizationalResource = State(initialValue: resource?.organizationalResource ?? "")
        _competence1 = State(initialValue: resource?.competence1 ?? "")
        _resourceCalendar = State(initialValue: resource?.resourceCalendar ?? "")
        _resourceStartDate = State(initialValue: resource?.resourceStartDate)
        _resourceFinishDate = State(initialValue: resource?.resourceFinishDate)
        _responsableOperationnel = State(initialValue: resource?.responsableOperationnel ?? "")
        _responsableInterne = State(initialValue: resource?.responsableInterne ?? "")
        _localisation = State(initialValue: resource?.localisation ?? "")
        _typeDeRessource = State(initialValue: resource?.typeDeRessource ?? "")
        _journeesTempsPartiel = State(initialValue: resource?.journeesTempsPartiel ?? "")
        _email = State(initialValue: resource?.email ?? "")
        _phone = State(initialValue: resource?.phone ?? "")
        _assignedProjectIDs = State(initialValue: Set(resource?.assignedProjectIDs ?? []))
        _templateResourceID = State(initialValue: resource?.templateResourceID)
        _memoFunctionName = State(initialValue: Self.memoInitial(resource?.memo.functionName, fallback: resource?.displayPrimaryRole ?? ""))
        _memoFunction = State(initialValue: Self.memoInitial(resource?.memo.function, fallback: resource?.displayPrimaryRole ?? ""))
        _memoHolder = State(initialValue: Self.memoInitial(resource?.memo.holder, fallback: resource?.displayName ?? ""))
        _memoReportsTo = State(initialValue: Self.memoInitial(resource?.memo.reportsTo, fallback: resource?.responsableOperationnel ?? resource?.responsableInterne ?? ""))
        _memoMainMission = State(initialValue: resource?.memo.mainMission ?? "")
        _memoResponsibleFor = State(initialValue: resource?.memo.responsibleFor ?? "")
        _memoDeliverables = State(initialValue: resource?.memo.deliverables ?? "")
        _memoWhatIDo = State(initialValue: resource?.memo.whatIDo ?? "")
        _memoWhatIDoButShouldNot = State(initialValue: resource?.memo.whatIDoButShouldNot ?? "")
        _memoWhatIDoNotDo = State(initialValue: resource?.memo.whatIDoNotDo ?? "")
        _memoNeeds = State(initialValue: resource?.memo.needs ?? "")
        _memoProvidesTo = State(initialValue: resource?.memo.providesTo ?? "")
        _memoMainTools = State(initialValue: Self.memoInitial(resource?.memo.mainTools, fallback: resource?.resourceCalendar ?? ""))
        _memoCurrentProjectOccupancyRate = State(initialValue: Self.memoInitial(resource?.memo.currentProjectOccupancyRate, fallback: resource.map { "\($0.allocationPercent)%" } ?? ""))
        _memoUpdatedAt = State(initialValue: resource?.memo.updatedAt)
        _notes = State(initialValue: resource?.notes ?? "")
    }

    private static func memoInitial(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    identiteSection
                    profilSection
                    planificationSection
                    gouvernanceSection
                    applicationSection
                    projectsSection
                    if assignedProjectIDs.isEmpty == false { templateSection }
                    memoSection
                    notesSection
                }
                .padding(24)
            }
            .background(.background)
            .navigationTitle(localized(resource == nil ? "Nouvelle ressource" : "Modifier la ressource"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Annuler")) { requestDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized(resource == nil ? "Créer" : "Enregistrer")) { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 760, minHeight: 640, idealHeight: 800, maxHeight: 900)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onExitCommand { requestDismiss() }
        .confirmationDialog(localized("Fermer le formulaire ?"), isPresented: $isShowingDismissConfirmation, titleVisibility: .visible) {
            if formIsInvalid == false {
                Button(localized("Enregistrer")) { save() }
            }
            Button(localized("Ignorer les modifications"), role: .destructive) { dismiss() }
            Button(localized("Continuer l'édition"), role: .cancel) {}
        } message: {
            Text(localized("Les informations déjà saisies peuvent être enregistrées ou abandonnées."))
        }
        .onAppear {
            applyPrimaryProjectDefaultIfNeeded()
            captureInitialSnapshotIfNeeded()
        }
    }

    private var identiteSection: some View {
        formSection(title: localized("Identité"), subtitle: localized("Informations principales et localisation de la ressource.")) {
            VStack(alignment: .leading, spacing: 16) {
                fieldStack(label: localized("Nom"), required: true) {
                    TextField(localized("Nom complet de la ressource"), text: $nom)
                        .textFieldStyle(.roundedBorder)
                        .frame(minHeight: 44)
                        .overlay(alignment: .trailing) {
                            if nomTouched && nomIsEmpty {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.samouraiDanger).padding(.trailing, 6)
                            }
                        }
                        .onChange(of: nom) { _, _ in if !nomIsEmpty { nomTouched = true } }
                    if nomTouched && nomIsEmpty {
                        Label(localized("Ce champ est obligatoire"), systemImage: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(Color.samouraiDanger)
                    }
                }
                textField(label: localized("Parent Description"),
                          placeholder: localized("Département ou rattachement"),
                          binding: $parentDescription)
                textField(label: localized("Localisation"),
                          placeholder: localized("Ville, site, ou bureau"),
                          binding: $localisation)
            }
        }
    }

    private var profilSection: some View {
        formSection(title: localized("Profil professionnel"), subtitle: localized("Rôle exercé et compétences clés.")) {
            VStack(alignment: .leading, spacing: 16) {
                textField(label: localized("Primary Resource Role"),
                          placeholder: localized("Rôle principal exercé"),
                          binding: $primaryResourceRole)
                textField(label: localized("Resource Roles"),
                          placeholder: localized("Rôles secondaires (séparés par des virgules)"),
                          binding: $resourceRoles)
                textField(label: localized("Compétence 1"),
                          placeholder: localized("Compétence ou expertise principale"),
                          binding: $competence1)
                textField(label: localized("Type de Ressource"),
                          placeholder: localized("Interne, externe, prestataire…"),
                          binding: $typeDeRessource)
            }
        }
    }

    private var planificationSection: some View {
        formSection(title: localized("Planification"), subtitle: localized("Calendrier et fenêtre d'engagement.")) {
            VStack(alignment: .leading, spacing: 16) {
                textField(label: localized("Resource Calendar"),
                          placeholder: localized("Calendrier de référence (ex. Standard FR)"),
                          binding: $resourceCalendar)
                fieldStack(label: localized("Resource Start Date")) {
                    DatePicker("", selection: optionalDateBinding($resourceStartDate), displayedComponents: .date)
                        .labelsHidden()
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                fieldStack(label: localized("Resource Finish Date")) {
                    DatePicker("", selection: optionalDateBinding($resourceFinishDate), displayedComponents: .date)
                        .labelsHidden()
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                textField(label: localized("Journée(s) temps partiel"),
                          placeholder: localized("Ex.: Lun, Mer, Ven"),
                          binding: $journeesTempsPartiel)
            }
        }
    }

    private var gouvernanceSection: some View {
        formSection(title: localized("Gouvernance"), subtitle: localized("Rattachement organisationnel et responsabilités.")) {
            VStack(alignment: .leading, spacing: 16) {
                textField(label: localized("Organizational Resource"),
                          placeholder: localized("Entité ou organisation de rattachement"),
                          binding: $organizationalResource)
                textField(label: localized("Responsable Opérationnel"),
                          placeholder: localized("Nom du responsable opérationnel"),
                          binding: $responsableOperationnel)
                textField(label: localized("Responsable Interne"),
                          placeholder: localized("Nom du responsable interne"),
                          binding: $responsableInterne)
            }
        }
    }

    private var applicationSection: some View {
        formSection(title: localized("Application"), subtitle: localized("Coordonnées de contact applicatives.")) {
            VStack(alignment: .leading, spacing: 16) {
                textField(label: localized("E-mail"),
                          placeholder: localized("prenom.nom@organisation.fr"),
                          binding: $email)
                textField(label: localized("Téléphone"),
                          placeholder: localized("+33 …"),
                          binding: $phone)
            }
        }
    }

    private var projectsSection: some View {
        formSection(title: localized("Projets affectés"), subtitle: localized("Liste des projets sur lesquels la ressource intervient.")) {
            VStack(alignment: .leading, spacing: 12) {
                if store.projects.isEmpty {
                    Text(localized("Aucun projet disponible"))
                        .foregroundStyle(.primary.opacity(0.7))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.projects) { project in
                            Toggle(
                                project.name,
                                isOn: Binding(
                                    get: { assignedProjectIDs.contains(project.id) },
                                    set: { isSelected in
                                        if isSelected { assignedProjectIDs.insert(project.id) }
                                        else { assignedProjectIDs.remove(project.id) }
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                Text(appState.resolvedPrimaryProjectID(in: store) == nil
                     ? localized("Aucun Projet Principal défini: affectation manuelle requise.")
                     : localized("Projet principal préaffecté automatiquement, modifiable à tout moment."))
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
    }

    private var templateSection: some View {
        formSection(title: localized("Ressource template"), subtitle: localized("Lien vers un modèle de l'annuaire global.")) {
            let candidates = store.resources.filter { $0.id != resource?.id && $0.assignedProjectIDs.isEmpty }
            VStack(alignment: .leading, spacing: 12) {
                if candidates.isEmpty {
                    Text(localized("Aucune ressource template disponible dans l'annuaire global."))
                        .foregroundStyle(.primary.opacity(0.7))
                        .font(.callout)
                } else {
                    fieldStack(label: localized("Template associé")) {
                        Picker("", selection: $templateResourceID) {
                            Text(localized("Aucun")).tag(UUID?.none)
                            ForEach(candidates) { candidate in
                                Text(candidate.displayName).tag(UUID?.some(candidate.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let tid = templateResourceID, let t = store.resource(with: tid) {
                            Text(localized("Rôle : \(t.displayPrimaryRole)") + " • " + localized("Dép. : \(t.displayDepartment)"))
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    }
                }
                Text(localized("Lie cette ressource de projet à un modèle de l'annuaire global (1 template → N ressources de projet)."))
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
    }

    private var notesSection: some View {
        formSection(title: localized("Notes"), subtitle: localized("Informations complémentaires.")) {
            fieldStack(label: localized("Notes opérationnelles")) {
                TextField(localized("Précisions, contraintes, points d'attention…"),
                          text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
            }
        }
    }

    private var memoSection: some View {
        formSection(
            title: localized("Fiche de poste - Ressource Humaine : \(memoDisplayFunctionName)"),
            subtitle: localized("Mémo fonctionnel rattaché à cette ressource.")
        ) {
            VStack(alignment: .leading, spacing: 24) {
                memoIdentitySection
                memoResponsibilitiesSection
                memoBoundariesSection
                memoDependenciesSection
                memoPracticalSection
            }
        }
    }

    private var memoIdentitySection: some View {
        memoGroup(title: localized("1. Identité & mission")) {
            VStack(alignment: .leading, spacing: 14) {
                textField(label: localized("Nom de la fonction"),
                          placeholder: localized("Nom de la fonction"),
                          binding: $memoFunctionName)
                textField(label: localized("Fonction"),
                          placeholder: localized("Fonction exercée"),
                          binding: $memoFunction)
                textField(label: localized("Titulaire"),
                          placeholder: localized("Nom du titulaire"),
                          binding: $memoHolder)
                textField(label: localized("Reporte à"),
                          placeholder: localized("Responsable ou rattachement"),
                          binding: $memoReportsTo)
                memoTextField(label: localized("Mission principale"),
                              placeholder: localized("Mission principale de la ressource"),
                              binding: $memoMainMission)
            }
        }
    }

    private var memoResponsibilitiesSection: some View {
        memoGroup(title: localized("2. Responsabilités clés & livrables attendus")) {
            VStack(alignment: .leading, spacing: 14) {
                memoTextField(label: localized("Responsable de"),
                              placeholder: localized("Activités, périmètres ou responsabilités"),
                              binding: $memoResponsibleFor)
                memoTextField(label: localized("Livrables"),
                              placeholder: localized("Livrables attendus"),
                              binding: $memoDeliverables)
            }
        }
    }

    private var memoBoundariesSection: some View {
        memoGroup(title: localized("3. Frontières du rôle")) {
            VStack(alignment: .leading, spacing: 14) {
                memoTextField(label: localized("Ce que je fais"),
                              placeholder: localized("Activités réalisées"),
                              binding: $memoWhatIDo)
                memoTextField(label: localized("Ce que je fais mais que je ne devrais pas faire"),
                              placeholder: localized("Activités à transférer ou clarifier"),
                              binding: $memoWhatIDoButShouldNot)
                memoTextField(label: localized("Ce que je ne fais pas"),
                              placeholder: localized("Hors périmètre explicite"),
                              binding: $memoWhatIDoNotDo)
            }
        }
    }

    private var memoDependenciesSection: some View {
        memoGroup(title: localized("4. Interdépendances")) {
            VStack(alignment: .leading, spacing: 14) {
                memoTextField(label: localized("J’ai besoin de"),
                              placeholder: localized("Entrants, décisions, validations ou supports nécessaires"),
                              binding: $memoNeeds)
                memoTextField(label: localized("Je fournis à"),
                              placeholder: localized("Destinataires et contributions fournies"),
                              binding: $memoProvidesTo)
            }
        }
    }

    private var memoPracticalSection: some View {
        memoGroup(title: localized("5. Infos pratiques")) {
            VStack(alignment: .leading, spacing: 14) {
                memoTextField(label: localized("Outils principaux"),
                              placeholder: localized("Applications, référentiels, canaux"),
                              binding: $memoMainTools)
                textField(label: localized("Taux d’occupation actuel sur le projet"),
                          placeholder: localized("Ex.: 80%"),
                          binding: $memoCurrentProjectOccupancyRate)
                fieldStack(label: localized("Date de mise à jour")) {
                    DatePicker("", selection: optionalDateBinding($memoUpdatedAt), displayedComponents: .date)
                        .labelsHidden()
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func textField(label: String, placeholder: String, binding: Binding<String>) -> some View {
        fieldStack(label: label) {
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private func memoTextField(label: String, placeholder: String, binding: Binding<String>) -> some View {
        fieldStack(label: label) {
            TextField(placeholder, text: binding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...7)
        }
    }

    @ViewBuilder
    private func memoGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.primary.opacity(0.7))
                }
            }
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
                Text(label).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                if required { Text("*").font(.subheadline).foregroundStyle(Color.samouraiDanger) }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nomIsEmpty: Bool { nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var formIsInvalid: Bool { nomIsEmpty }

    private var snapshot: String {
        [
            nom, parentDescription, primaryResourceRole, resourceRoles, organizationalResource,
            competence1, resourceCalendar,
            resourceStartDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            resourceFinishDate.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            responsableOperationnel, responsableInterne, localisation, typeDeRessource,
            journeesTempsPartiel, email, phone,
            assignedProjectIDs.map(\.uuidString).sorted().joined(separator: ","),
            templateResourceID?.uuidString ?? "",
            memoFunctionName, memoFunction, memoHolder, memoReportsTo, memoMainMission,
            memoResponsibleFor, memoDeliverables, memoWhatIDo, memoWhatIDoButShouldNot,
            memoWhatIDoNotDo, memoNeeds, memoProvidesTo, memoMainTools,
            memoCurrentProjectOccupancyRate,
            memoUpdatedAt.map { String($0.timeIntervalSinceReferenceDate) } ?? "",
            notes
        ].joined(separator: "|")
    }

    private var memoDisplayFunctionName: String {
        let trimmed = memoFunctionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localized("Nom de la Fonction") : trimmed
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private func requestDismiss() {
        if hasUnsavedChanges { isShowingDismissConfirmation = true }
        else { dismiss() }
    }

    private func captureInitialSnapshotIfNeeded() {
        if initialSnapshot == nil { initialSnapshot = snapshot }
    }

    private func save() {
        let trimmedNom = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNom.isEmpty == false else {
            nomTouched = true
            return
        }

        if let resource {
            store.updateResource(
                resourceID: resource.id,
                nom: trimmedNom,
                parentDescription: trimmedOptional(parentDescription),
                primaryResourceRole: trimmedOptional(primaryResourceRole),
                resourceRoles: trimmedOptional(resourceRoles),
                organizationalResource: trimmedOptional(organizationalResource),
                competence1: trimmedOptional(competence1),
                resourceCalendar: trimmedOptional(resourceCalendar),
                resourceStartDate: resourceStartDate,
                resourceFinishDate: resourceFinishDate,
                responsableOperationnel: trimmedOptional(responsableOperationnel),
                responsableInterne: trimmedOptional(responsableInterne),
                localisation: trimmedOptional(localisation),
                typeDeRessource: trimmedOptional(typeDeRessource),
                journeesTempsPartiel: trimmedOptional(journeesTempsPartiel),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                assignedProjectIDs: normalizedAssignedProjectIDs(),
                memo: memoPayload(),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            applyTemplateLink(resourceID: resource.id)
            appState.selectedResourceID = resource.id
        } else {
            let resourceID = store.addResource(
                nom: trimmedNom,
                parentDescription: trimmedOptional(parentDescription),
                primaryResourceRole: trimmedOptional(primaryResourceRole),
                resourceRoles: trimmedOptional(resourceRoles),
                organizationalResource: trimmedOptional(organizationalResource),
                competence1: trimmedOptional(competence1),
                resourceCalendar: trimmedOptional(resourceCalendar),
                resourceStartDate: resourceStartDate,
                resourceFinishDate: resourceFinishDate,
                responsableOperationnel: trimmedOptional(responsableOperationnel),
                responsableInterne: trimmedOptional(responsableInterne),
                localisation: trimmedOptional(localisation),
                typeDeRessource: trimmedOptional(typeDeRessource),
                journeesTempsPartiel: trimmedOptional(journeesTempsPartiel),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                assignedProjectIDs: normalizedAssignedProjectIDs(),
                memo: memoPayload(),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            applyTemplateLink(resourceID: resourceID)
            appState.selectedResourceID = resourceID
        }

        appState.selectedSection = .resources
        dismiss()
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func memoPayload() -> ResourceMemo {
        ResourceMemo(
            functionName: trimmed(memoFunctionName),
            function: trimmed(memoFunction),
            holder: trimmed(memoHolder),
            reportsTo: trimmed(memoReportsTo),
            mainMission: trimmed(memoMainMission),
            responsibleFor: trimmed(memoResponsibleFor),
            deliverables: trimmed(memoDeliverables),
            whatIDo: trimmed(memoWhatIDo),
            whatIDoButShouldNot: trimmed(memoWhatIDoButShouldNot),
            whatIDoNotDo: trimmed(memoWhatIDoNotDo),
            needs: trimmed(memoNeeds),
            providesTo: trimmed(memoProvidesTo),
            mainTools: trimmed(memoMainTools),
            currentProjectOccupancyRate: trimmed(memoCurrentProjectOccupancyRate),
            updatedAt: memoUpdatedAt
        )
    }

    private func optionalDateBinding(_ binding: Binding<Date?>) -> Binding<Date> {
        Binding<Date>(
            get: { binding.wrappedValue ?? .now },
            set: { binding.wrappedValue = $0 }
        )
    }

    private func applyTemplateLink(resourceID: UUID) {
        if let tid = templateResourceID {
            store.assignTemplate(resourceID: resourceID, templateID: tid)
        } else {
            store.unassignTemplate(resourceID: resourceID)
        }
    }

    private func normalizedAssignedProjectIDs() -> [UUID] {
        store.projects.map(\.id).filter { assignedProjectIDs.contains($0) }
    }

    private func applyPrimaryProjectDefaultIfNeeded() {
        guard didApplyPrimaryProjectDefault == false else { return }
        didApplyPrimaryProjectDefault = true
        guard resource == nil, assignedProjectIDs.isEmpty else { return }
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            assignedProjectIDs.insert(primaryProjectID)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
