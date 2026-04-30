import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ReportingWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(SamouraiStore.self) private var store

    @State private var cadence: ReportingCadence = .weekly
    @State private var selectedScopeKey: String = "portfolio"
    @State private var selectedReportID: UUID?

    @State private var executiveSummaryPMDraft = ""
    @State private var planningActionsPMDraft = ""
    @State private var conclusionPMDraft = ""

    @State private var isShowingMarkdownExporter = false
    @State private var isShowingTextExporter = false
    @State private var isShowingPDFExporter = false
    @State private var markdownDocument: ReportingMarkdownDocument?
    @State private var textDocument: ReportingTextDocument?
    @State private var pdfDocument: ReportingBinaryDocument?
    @State private var exportFilename = "samourai-reporting"
    @State private var reportPendingDeletion: GovernanceReportRecord?
    @State private var hiddenSections: Set<String> = []

    var body: some View {
        mainView
            .fileExporter(
                isPresented: $isShowingMarkdownExporter,
                document: markdownDocument,
                contentType: ReportingMarkdownDocument.writableContentTypes[0],
                defaultFilename: "\(exportFilename).md"
            ) { _ in }
            .fileExporter(
                isPresented: $isShowingTextExporter,
                document: textDocument,
                contentType: .plainText,
                defaultFilename: "\(exportFilename).txt"
            ) { _ in }
            .fileExporter(
                isPresented: $isShowingPDFExporter,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: "\(exportFilename).pdf"
            ) { _ in }
            .confirmationDialog(localized("Supprimer ce rapport ?"),
                isPresented: Binding(
                    get: { reportPendingDeletion != nil },
                    set: { if $0 == false { reportPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let record = reportPendingDeletion {
                    Button(localized("Supprimer"), role: .destructive) {
                        store.deleteGovernanceReportRecord(reportID: record.id)
                        reportPendingDeletion = nil
                    }
                }
                Button(localized("Annuler"), role: .cancel) { reportPendingDeletion = nil }
            } message: {
                Text(localized("Cette action est irréversible. Le rapport sera définitivement supprimé de l'archive."))
            }
    }

    private var mainView: some View {
        SamouraiWorkspaceSplitView(sidebarMinWidth: 320, sidebarIdealWidth: 356) {
            archiveSidebar
        } detail: {
            reportDetailPane
        }
        .onAppear {
            cadence = appState.reportingCadence
            selectedScopeKey = defaultScopeKey
            selectInitialReportIfNeeded()
            loadEditorDraftFromSelection()
        }
        .onChange(of: cadence) { _, newCadence in
            appState.reportingCadence = newCadence
        }
        .onChange(of: selectedScopeKey) { _, _ in
            if selectedReportID == nil { selectInitialReportIfNeeded() }
        }
        .onChange(of: selectedReportID) { _, _ in
            loadEditorDraftFromSelection()
        }
        .onChange(of: store.governanceReports.map(\.id)) { _, _ in
            if selectedReportID != nil, selectedRecord == nil {
                self.selectedReportID = filteredArchive.first?.id
            } else if selectedReportID == nil {
                selectedReportID = filteredArchive.first?.id
            }
            loadEditorDraftFromSelection()
        }
    }

    private var archiveSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            SamouraiPageHeader(
                eyebrow: "Reporting",
                title: "Gouvernance",
                subtitle: "Prépare, archive et réédite les synthèses sans quitter le flux de travail."
            )

            SamouraiSectionCard(
                title: "Paramètres",
                subtitle: "Choisis la cadence et le périmètre avant génération."
            ) {
                Picker(localized("Cadence"), selection: $cadence) {
                    ForEach(ReportingCadence.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker(localized("Périmètre"), selection: $selectedScopeKey) {
                    Text(localized("Portefeuille complet")).tag("portfolio")
                    if let primary = resolvedPrimaryProject {
                        Text(appState.localizedFormat("Projet principal: %@", primary.name)).tag("primary")
                    }
                    ForEach(store.projects) { project in
                        Text(appState.localizedFormat("Projet: %@", project.name)).tag(projectScopeKey(project.id))
                    }
                }
                .pickerStyle(.menu)

                Button(localized("Générer le rapport")) {
                    generateOneClickReport()
                }
                .buttonStyle(.borderedProminent)
            }

            SamouraiSectionCard(
                title: "Historique",
                subtitle: "Chaque rapport sauvegardé reste réutilisable et exportable."
            ) {
                if filteredArchive.isEmpty {
                    SamouraiEmptyStateCard(
                        title: "Aucun rapport",
                        systemImage: "clock.arrow.circlepath",
                        description: "Génère un premier rapport pour activer l’archive."
                    )
                } else {
                    List(selection: $selectedReportID) {
                        ForEach(filteredArchive) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.generatedReport.cadence.label)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    SamouraiStatusPill(
                                        text: record.generatedReport.scopeLabel,
                                        tint: SamouraiSurface.accent
                                    )
                                }

                                Text(record.generatedReport.periodLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .tag(record.id)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 260)
                    .scrollIndicators(.visible)
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var reportDetailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SamouraiLayout.sectionSpacing) {
                if let record = selectedRecord {
                    SamouraiPageHeader(
                        eyebrow: "Rapport",
                        title: "Synthèse de gouvernance",
                        subtitle: "Vue éditable, exportable et relisible rapidement pour préparer les instances."
                    )

                    HStack(spacing: 10) {
                        Button(localized("Enregistrer")) {
                            savePMEdits(recordID: record.id)
                        }
                        .buttonStyle(.borderedProminent)

                        Menu(localized("Exporter")) {
                            Button(localized("Markdown (.md)")) { exportAsMarkdown(record) }
                            Button(localized("Texte brut (.txt)")) { exportAsText(record) }
                            Button(localized("PDF professionnel (.pdf)")) { exportAsPDF(record) }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            reportPendingDeletion = record
                        } label: {
                            Label(localized("Supprimer"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }

                    sectionCard(
                        id: "context",
                        title: "Contexte",
                        subtitle: "Le cadre du rapport reste visible immédiatement pour limiter les ambiguïtés."
                    ) {
                        Text(appState.localizedFormat("Période couverte: %@", record.periodLabel))
                        Text(appState.localizedFormat("Projets concernés: %@", record.projectsLabel))
                        Text(appState.localizedFormat("Généré le: %@", record.createdAt.formatted(date: .abbreviated, time: .shortened)))
                            .foregroundStyle(.secondary)
                    }

                    sectionCard(
                        id: "executive",
                        title: "Résumé exécutif",
                        subtitle: "Indicateurs automatiques et note PM regroupés dans un seul bloc."
                    ) {
                        ForEach(record.executiveHighlightsAuto.prefix(4), id: \.self) { line in
                            Label(line, systemImage: "checkmark.circle")
                        }
                        Divider()
                        TextEditor(text: $executiveSummaryPMDraft)
                            .font(.body)
                            .samouraiEditorSurface(minHeight: 88)
                    }

                    sectionCard(
                        id: "accomplishments",
                        title: "Accomplissements",
                        subtitle: "Les éléments livrés sont listés de façon simple et scannable."
                    ) {
                        if record.generatedReport.accomplishments.isEmpty {
                            Text(localized("Aucun accomplissement détecté automatiquement."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.generatedReport.accomplishments.prefix(8), id: \.self) { line in
                                Label(line, systemImage: "checkmark.circle")
                            }
                        }
                    }

                    sectionCard(
                        id: "tests",
                        title: "Avancement des tests",
                        subtitle: "Le statut qualité reste visible sans surcharger l’écran."
                    ) {
                        ForEach(record.testsProgressAutoLines, id: \.self) { line in
                            Label(line, systemImage: "testtube.2")
                        }
                    }

                    sectionCard(
                        id: "risks",
                        title: "Risques, problèmes et blocages",
                        subtitle: "Les signaux d’alerte sont regroupés dans une zone dédiée."
                    ) {
                        ForEach(record.risksAndBlocksAutoLines.prefix(8), id: \.self) { line in
                            Label(line, systemImage: "exclamationmark.triangle")
                        }
                    }

                    sectionCard(
                        id: "planning",
                        title: "Planification prochaine",
                        subtitle: "Les prochaines actions attendues sont séparées du diagnostic pour faciliter la lecture."
                    ) {
                        if record.nextPlanningAutoLines.isEmpty {
                            Text(localized("Aucun jalon/livrable/action à court terme détecté."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.nextPlanningAutoLines.prefix(8), id: \.self) { line in
                                Label(line, systemImage: "calendar")
                            }
                        }
                        Divider()
                        TextEditor(text: $planningActionsPMDraft)
                            .font(.body)
                            .samouraiEditorSurface(minHeight: 88)
                    }

                    sectionCard(
                        id: "conclusion",
                        title: "Commentaire du chef de projet",
                        subtitle: "Le PM pose ici une synthèse claire à destination des décideurs."
                    ) {
                        TextEditor(text: $conclusionPMDraft)
                            .font(.body)
                            .samouraiEditorSurface(minHeight: 88)
                    }
                } else {
                    SamouraiEmptyStateCard(
                        title: "Aucun rapport sélectionné",
                        systemImage: "doc.text.magnifyingglass",
                        description: "Génère un rapport en un clic ou sélectionne un rapport archivé."
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .padding(SamouraiLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .samouraiCanvasBackground()
    }

    private func sectionCard<Content: View>(
        id: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let isHidden = hiddenSections.contains(id)
        return SamouraiSectionCard(title: title, subtitle: subtitle, trailing: {
            Button {
                if isHidden { hiddenSections.remove(id) } else { hiddenSections.insert(id) }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }) {
            if !isHidden { content() }
        }
    }

    private var filteredArchive: [GovernanceReportRecord] {
        store.governanceReportArchive(scopedProjectID: filterProjectID)
            .filter { $0.generatedReport.cadence == cadence }
    }

    private var selectedRecord: GovernanceReportRecord? {
        guard let selectedReportID else { return filteredArchive.first }
        return filteredArchive.first(where: { $0.id == selectedReportID })
    }

    private var resolvedPrimaryProject: Project? {
        guard let projectID = appState.resolvedPrimaryProjectID(in: store) else { return nil }
        return store.project(with: projectID)
    }

    private var defaultScopeKey: String {
        resolvedPrimaryProject == nil ? "portfolio" : "primary"
    }

    private var filterProjectID: UUID? {
        if selectedScopeKey == "portfolio" {
            return nil
        }
        if selectedScopeKey == "primary" {
            return resolvedPrimaryProject?.id
        }
        return projectIDFromScopeKey(selectedScopeKey)
    }

    private func projectScopeKey(_ projectID: UUID) -> String {
        "project:\(projectID.uuidString)"
    }

    private func projectIDFromScopeKey(_ key: String) -> UUID? {
        guard key.hasPrefix("project:") else { return nil }
        let raw = String(key.dropFirst("project:".count))
        return UUID(uuidString: raw)
    }

    private func selectInitialReportIfNeeded() {
        if selectedReportID == nil {
            selectedReportID = filteredArchive.first?.id
        }
    }

    private func generateOneClickReport() {
        let scopedProjectIDs: [UUID]?
        let scopeLabel: String

        if selectedScopeKey == "portfolio" {
            scopedProjectIDs = nil
            scopeLabel = "Portefeuille complet"
        } else if selectedScopeKey == "primary", let primary = resolvedPrimaryProject {
            scopedProjectIDs = [primary.id]
            scopeLabel = "Projet principal: \(primary.name)"
        } else if let selectedProjectID = projectIDFromScopeKey(selectedScopeKey),
                  let project = store.project(with: selectedProjectID) {
            scopedProjectIDs = [selectedProjectID]
            scopeLabel = "Projet: \(project.name)"
        } else {
            return
        }

        let generated = store.governanceReport(
            cadence: cadence,
            scopedProjectIDs: scopedProjectIDs,
            scopeLabel: scopeLabel
        )

        let prefilledExecutive = generated.accomplishments.prefix(2).joined(separator: " ")
        let prefilledPlanning = generated.nextSteps.prefix(2).joined(separator: " ")

        let reportID = store.saveGovernanceReportRecord(
            generatedReport: generated,
            scopedProjectIDs: scopedProjectIDs,
            executiveSummaryPMNote: prefilledExecutive,
            planningActionsPMNote: prefilledPlanning,
            conclusionPMMessage: ""
        )
        selectedReportID = reportID
    }

    private func loadEditorDraftFromSelection() {
        guard let record = selectedRecord else {
            executiveSummaryPMDraft = ""
            planningActionsPMDraft = ""
            conclusionPMDraft = ""
            return
        }
        executiveSummaryPMDraft = record.executiveSummaryPMNote
        planningActionsPMDraft = record.planningActionsPMNote
        conclusionPMDraft = record.conclusionPMMessage
    }

    private func savePMEdits(recordID: UUID) {
        store.updateGovernanceReportRecord(
            reportID: recordID,
            executiveSummaryPMNote: executiveSummaryPMDraft,
            planningActionsPMNote: planningActionsPMDraft,
            conclusionPMMessage: conclusionPMDraft
        )
    }

    private func exportAsMarkdown(_ record: GovernanceReportRecord) {
        exportFilename = filenameBase(for: record)
        markdownDocument = ReportingMarkdownDocument(text: record.markdownOnePager)
        Task { @MainActor in isShowingMarkdownExporter = true }
    }

    private func exportAsText(_ record: GovernanceReportRecord) {
        exportFilename = filenameBase(for: record)
        textDocument = ReportingTextDocument(text: record.plainTextOnePager)
        Task { @MainActor in isShowingTextExporter = true }
    }

    private func exportAsPDF(_ record: GovernanceReportRecord) {
        exportFilename = filenameBase(for: record)
        let pdfData = renderPDFData(from: record)
        pdfDocument = ReportingBinaryDocument(data: pdfData)
        Task { @MainActor in isShowingPDFExporter = true }
    }

    private func filenameBase(for record: GovernanceReportRecord) -> String {
        let day = record.generatedReport.periodStart.formatted(.dateTime.year().month().day())
        return "samourai-\(record.generatedReport.cadence.rawValue)-\(day)"
    }

    private func renderPDFData(from record: GovernanceReportRecord) -> Data {
        let content = ReportPDFContent(record: record, appState: appState)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        let mutableData = NSMutableData()
        renderer.render { size, renderContext in
            guard let consumer = CGDataConsumer(data: mutableData) else { return }
            var mediaBox = CGRect(origin: .zero, size: CGSize(width: size.width, height: max(size.height, 842)))
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            renderContext(context)
            context.endPDFPage()
            context.closePDF()
        }
        return mutableData as Data
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}

private struct ReportingMarkdownDocument: FileDocument {
    static let markdownType: UTType = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static var readableContentTypes: [UTType] { [markdownType, .plainText] }
    static var writableContentTypes: [UTType] { [markdownType] }

    let data: Data

    init(text: String) {
        self.data = text.data(using: .utf8) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct ReportingTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    let data: Data

    init(text: String) {
        self.data = text.data(using: .utf8) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct ReportingBinaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

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

private struct ReportPDFContent: View {
    let record: GovernanceReportRecord
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localized("RAPPORT GOUVERNANCE"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.blue)
                    .tracking(0.8)
                Text(record.title)
                    .font(.largeTitle.weight(.bold))
                Text(appState.localizedFormat("Période: %@", record.periodLabel))
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(appState.localizedFormat("Projets: %@", record.projectsLabel))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            pdfSection("1. Résumé Exécutif") {
                ForEach(record.executiveHighlightsAuto.prefix(4), id: \.self) { line in
                    Label(line, systemImage: "checkmark.circle").font(.body)
                }
                if !record.executiveSummaryPMNote.isEmpty {
                    Text(record.executiveSummaryPMNote)
                        .font(.body)
                        .padding(.top, 4)
                }
            }

            pdfSection("2. Accomplissements") {
                let items = record.generatedReport.accomplishments
                if items.isEmpty {
                    Text(localized("Aucun accomplissement détecté automatiquement.")).font(.body).foregroundStyle(.secondary)
                } else {
                    ForEach(items.prefix(8), id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle").font(.body)
                    }
                }
            }

            pdfSection("3. Avancement des Tests") {
                ForEach(record.testsProgressAutoLines, id: \.self) { line in
                    Label(line, systemImage: "testtube.2").font(.body)
                }
            }

            pdfSection("4. Risques, Problèmes & Blocages") {
                ForEach(record.risksAndBlocksAutoLines.prefix(8), id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.triangle").font(.body)
                }
            }

            pdfSection("5. Planification Prochaine") {
                let items = record.nextPlanningAutoLines
                if items.isEmpty {
                    Text(localized("Aucun jalon/livrable/action à court terme détecté.")).font(.body).foregroundStyle(.secondary)
                } else {
                    ForEach(items.prefix(8), id: \.self) { line in
                        Label(line, systemImage: "calendar").font(.body)
                    }
                }
                if !record.planningActionsPMNote.isEmpty {
                    Text(record.planningActionsPMNote).font(.body).padding(.top, 4)
                }
            }

            pdfSection("6. Commentaire du Chef de Projet") {
                if record.conclusionPMMessage.isEmpty {
                    Text(localized("Aucun commentaire.")).font(.body).foregroundStyle(.secondary)
                } else {
                    Text(record.conclusionPMMessage).font(.body)
                }
            }
        }
        .padding(44)
        .frame(width: 595)
        .background(Color.white)
    }

    @ViewBuilder
    private func pdfSection<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading)
                .font(.headline)
            content()
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalizer.localized(key, language: appState.interfaceLanguage)
    }
}
