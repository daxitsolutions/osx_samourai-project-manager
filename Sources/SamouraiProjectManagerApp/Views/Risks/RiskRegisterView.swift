import SwiftUI
import UniformTypeIdentifiers

struct RiskRegisterView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var isShowingFileImporter = false
    @State private var isShowingManualRiskEditor = false
    @State private var importFeedbackMessage: String?
    @State private var isImporting = false

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Registre global des risques")
                            .font(.title2.weight(.semibold))
                        Text("\(scopedRisks.count) risque(s) suivi(s)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isShowingManualRiskEditor = true
                    } label: {
                        Label("Nouveau risque", systemImage: "plus")
                    }
                    .disabled(store.projects.isEmpty)

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Importer", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if scopedRisks.isEmpty {
                    ContentUnavailableView(
                        "Aucun risque",
                        systemImage: "checkmark.shield",
                        description: Text("Les risques créés ou importés apparaîtront ici.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(scopedRisks, selection: $appState.selectedRiskID) {
                        TableColumn("ID") { entry in
                            Text(entry.risk.externalID ?? "-")
                        }

                        TableColumn("Titre") { entry in
                            TextField(
                                "Titre",
                                text: Binding(
                                    get: { entry.risk.displayTitle },
                                    set: {
                                        store.updateRiskQuick(
                                            riskID: entry.risk.id,
                                            title: $0,
                                            owner: entry.risk.displayOwner,
                                            severity: entry.risk.severity,
                                            status: entry.risk.riskStatus ?? ""
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                        }

                        TableColumn("Projet(s)") { entry in
                            Text(entry.risk.projectNames ?? entry.projectName)
                        }

                        TableColumn("Assigné à") { entry in
                            TextField(
                                "Owner",
                                text: Binding(
                                    get: { entry.risk.displayOwner },
                                    set: {
                                        store.updateRiskQuick(
                                            riskID: entry.risk.id,
                                            title: entry.risk.displayTitle,
                                            owner: $0,
                                            severity: entry.risk.severity,
                                            status: entry.risk.riskStatus ?? ""
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                        }

                        TableColumn("Sévérité") { entry in
                            Picker(
                                "Sévérité",
                                selection: Binding(
                                    get: { entry.risk.severity },
                                    set: {
                                        store.updateRiskQuick(
                                            riskID: entry.risk.id,
                                            title: entry.risk.displayTitle,
                                            owner: entry.risk.displayOwner,
                                            severity: $0,
                                            status: entry.risk.riskStatus ?? ""
                                        )
                                    }
                                )
                            ) {
                                ForEach(RiskSeverity.allCases) { severity in
                                    Text(severity.label).tag(severity)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        TableColumn("Statut") { entry in
                            TextField(
                                "Statut",
                                text: Binding(
                                    get: { entry.risk.riskStatus ?? "" },
                                    set: {
                                        store.updateRiskQuick(
                                            riskID: entry.risk.id,
                                            title: entry.risk.displayTitle,
                                            owner: entry.risk.displayOwner,
                                            severity: entry.risk.severity,
                                            status: $0
                                        )
                                    }
                                )
                            )
                            .textFieldStyle(.plain)
                        }

                        TableColumn("Score") { entry in
                            Text(scoreLabel(for: entry.risk.score0to10))
                        }
                    }
                }
            }
            .frame(minWidth: 620, idealWidth: 760)

            Group {
                if let selectedRiskID = appState.selectedRiskID,
                   let risk = store.risk(with: selectedRiskID) {
                    RiskDetailView(
                        risk: risk,
                        fallbackProjectName: scopedRisks.first(where: { $0.risk.id == selectedRiskID })?.projectName
                    )
                } else {
                    ContentUnavailableView(
                        "Sélectionne un risque",
                        systemImage: "exclamationmark.triangle",
                        description: Text("La fiche détail affiche tous les attributs importés du registre de risques.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "xlsx") ?? .data,
                .commaSeparatedText,
                .tabSeparatedText
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: $isShowingManualRiskEditor) {
            ManualRiskEditorSheet(
                suggestedProjectID: appState.resolvedPrimaryProjectID(in: store)
            )
        }
        .alert("Import des risques", isPresented: Binding(
            get: { importFeedbackMessage != nil },
            set: { if $0 == false { importFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importFeedbackMessage ?? "")
        }
        .padding(0)
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else {
            if case .failure(let error) = result {
                importFeedbackMessage = error.localizedDescription
            }
            return
        }

        isImporting = true
        let didAccessSecurityScope = fileURL.startAccessingSecurityScopedResource()

        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
            isImporting = false
        }

        do {
            let drafts = try RiskImportService.importRisks(from: fileURL)
            let importResult = store.importRisks(drafts)

            if let riskID = importResult.firstImportedOrUpdatedRiskID {
                appState.openRisk(riskID)
            }

            importFeedbackMessage = "Import terminé : \(importResult.summary)"
        } catch {
            importFeedbackMessage = error.localizedDescription
        }
    }

    private func scoreLabel(for score: Double?) -> String {
        guard let score else { return "-" }
        return score.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var scopedRisks: [RiskEntry] {
        if let primaryProjectID = appState.resolvedPrimaryProjectID(in: store) {
            return store.risks.filter { $0.projectID == primaryProjectID }
        }
        return store.risks
    }
}

private struct ManualRiskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    let suggestedProjectID: UUID?

    @State private var projectID: UUID?
    @State private var title = ""
    @State private var mitigation = ""
    @State private var owner = ""
    @State private var severity: RiskSeverity = .medium
    @State private var dueDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Picker("Projet", selection: $projectID) {
                    Text("Sélectionner").tag(Optional<UUID>.none)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                TextField("Risque", text: $title)
                TextField("Mitigation", text: $mitigation, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Owner", text: $owner)

                Picker("Sévérité", selection: $severity) {
                    ForEach(RiskSeverity.allCases) { entry in
                        Text(entry.label).tag(entry)
                    }
                }

                DatePicker("Date d'action cible", selection: $dueDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouveau risque")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        guard let projectID else { return }
                        store.addRisk(
                            to: projectID,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            mitigation: mitigation.trimmingCharacters(in: .whitespacesAndNewlines),
                            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
                            severity: severity,
                            dueDate: dueDate
                        )
                        appState.selectedSection = .risks
                        dismiss()
                    }
                    .disabled(formIsInvalid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 380)
        .onAppear {
            if projectID == nil {
                projectID = suggestedProjectID ?? store.projects.first?.id
            }
        }
    }

    private var formIsInvalid: Bool {
        projectID == nil
            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct RiskDetailView: View {
    let risk: Risk
    let fallbackProjectName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(risk.displayTitle)
                        .font(.largeTitle.weight(.semibold))

                    HStack(spacing: 18) {
                        Label(risk.projectNames ?? fallbackProjectName ?? "Sans projet", systemImage: "folder")
                        Label(risk.displayOwner.isEmpty ? "Non assigné" : risk.displayOwner, systemImage: "person.crop.circle")
                        Label(risk.displayStatus, systemImage: "checkmark.seal")
                        Label(scoreLabel(for: risk.score0to10), systemImage: "number")
                    }
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Attributs du risque")
                        .font(.title2.weight(.semibold))

                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            detailCard(title: "ID", value: risk.externalID ?? "-")
                            detailCard(title: "Projet(s)", value: risk.projectNames ?? fallbackProjectName ?? "-")
                            detailCard(title: "Détecté par", value: risk.detectedBy ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Assigné à", value: risk.assignedTo ?? "-")
                            detailCard(title: "Date de création", value: formattedDate(risk.createdAt))
                            detailCard(title: "Dernière modification", value: formattedDate(risk.lastModifiedAt))
                        }

                        GridRow {
                            detailCard(title: "Type de risque", value: risk.riskType ?? "-")
                            detailCard(title: "Réponse", value: risk.response ?? "-")
                            detailCard(title: "Origine du risque", value: risk.riskOrigin ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Proximité", value: risk.proximity ?? "-")
                            detailCard(title: "Probabilité", value: risk.probability ?? "-")
                            detailCard(title: "Niveau d'escalation", value: risk.escalationLevel ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Impact Périmètre", value: risk.impactScope ?? "-")
                            detailCard(title: "Impact Budget", value: risk.impactBudget ?? "-")
                            detailCard(title: "Impact Planning", value: risk.impactPlanning ?? "-")
                        }

                        GridRow {
                            detailCard(title: "Impact Ressources", value: risk.impactResources ?? "-")
                            detailCard(title: "Impact Transition", value: risk.impactTransition ?? "-")
                            detailCard(title: "Impact Sécurité IT", value: risk.impactSecurityIT ?? "-")
                        }
                    }
                }

                longTextSection(title: "Description de l'impact", value: risk.impactDescription)
                longTextSection(title: "Contre-mesure", value: risk.counterMeasure)
                longTextSection(title: "Commentaire / Suivi", value: risk.followUpComment)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func longTextSection(title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text((value?.isEmpty == false ? value! : "Non renseigné"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func scoreLabel(for score: Double?) -> String {
        guard let score else { return "-" }
        return score.formatted(.number.precision(.fractionLength(0...1)))
    }
}
