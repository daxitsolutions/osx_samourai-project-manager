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
    @State private var markdownDocument: ReportingTextDocument?
    @State private var textDocument: ReportingTextDocument?
    @State private var pdfDocument: ReportingBinaryDocument?
    @State private var exportFilename = "samourai-reporting"

    var body: some View {
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
            if selectedReportID == nil {
                selectInitialReportIfNeeded()
            }
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
        .fileExporter(
            isPresented: $isShowingMarkdownExporter,
            document: markdownDocument,
            contentType: .plainText,
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
                Picker("Cadence", selection: $cadence) {
                    ForEach(ReportingCadence.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Périmètre", selection: $selectedScopeKey) {
                    Text("Portefeuille complet").tag("portfolio")
                    if let primary = resolvedPrimaryProject {
                        Text("Projet principal: \(primary.name)").tag("primary")
                    }
                    ForEach(store.projects) { project in
                        Text("Projet: \(project.name)").tag(projectScopeKey(project.id))
                    }
                }
                .pickerStyle(.menu)

                Button("Générer le rapport") {
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
                        subtitle: "Une vue éditable, exportable et relisible rapidement pour préparer les instances."
                    ) {
                        HStack(spacing: 10) {
                            Button("Enregistrer") {
                                savePMEdits(recordID: record.id)
                            }
                            .buttonStyle(.borderedProminent)

                            Menu("Exporter") {
                                Button("Markdown (.md)") {
                                    exportAsMarkdown(record)
                                }
                                Button("Texte brut (.txt)") {
                                    exportAsText(record)
                                }
                                Button("PDF professionnel (.pdf)") {
                                    exportAsPDF(record)
                                }
                            }

                            Button(role: .destructive) {
                                store.deleteGovernanceReportRecord(reportID: record.id)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    sectionCard(
                        title: "Contexte",
                        subtitle: "Le cadre du rapport reste visible immédiatement pour limiter les ambiguïtés."
                    ) {
                        Text("Période couverte: \(record.periodLabel)")
                        Text("Projets concernés: \(record.projectsLabel)")
                        Text("Généré le: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }

                    sectionCard(
                        title: "Résumé exécutif",
                        subtitle: "Le résumé automatique et l’affinage PM sont regroupés dans un seul bloc."
                    ) {
                        ForEach(record.executiveHighlightsAuto.prefix(4), id: \.self) { line in
                            Label(line, systemImage: "checkmark.circle")
                        }
                        Divider()
                        Text("Affinage PM (éditable)")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $executiveSummaryPMDraft)
                            .font(.body)
                            .samouraiEditorSurface(minHeight: 88)
                    }

                    sectionCard(
                        title: "Accomplissements",
                        subtitle: "Les éléments livrés sont listés de façon simple et scannable."
                    ) {
                        if record.generatedReport.accomplishments.isEmpty {
                            Text("Aucun accomplissement détecté automatiquement.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.generatedReport.accomplishments.prefix(8), id: \.self) { line in
                                Label(line, systemImage: "checkmark.circle")
                            }
                        }
                    }

                    sectionCard(
                        title: "Avancement des tests",
                        subtitle: "Le statut qualité reste visible sans surcharger l’écran."
                    ) {
                        ForEach(record.testsProgressAutoLines, id: \.self) { line in
                            Label(line, systemImage: "testtube.2")
                        }
                    }

                    sectionCard(
                        title: "Risques, problèmes et blocages",
                        subtitle: "Les signaux d’alerte sont regroupés dans une zone dédiée."
                    ) {
                        ForEach(record.risksAndBlocksAutoLines.prefix(8), id: \.self) { line in
                            Label(line, systemImage: "exclamationmark.triangle")
                        }
                    }

                    sectionCard(
                        title: "Planification prochaine",
                        subtitle: "Les prochaines actions attendues sont séparées du diagnostic pour faciliter la lecture."
                    ) {
                        if record.nextPlanningAutoLines.isEmpty {
                            Text("Aucun jalon/livrable/action à court terme détecté.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.nextPlanningAutoLines.prefix(8), id: \.self) { line in
                                Label(line, systemImage: "calendar")
                            }
                        }
                        Divider()
                        Text("Actions spécifiques attendues de l'équipe (éditable)")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $planningActionsPMDraft)
                            .font(.body)
                            .samouraiEditorSurface(minHeight: 88)
                    }

                    sectionCard(
                        title: "Conclusion et actions requises",
                        subtitle: "Le PM peut poser ici une synthèse claire à destination des décideurs."
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

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        SamouraiSectionCard(title: title, subtitle: subtitle) {
            content()
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
        markdownDocument = ReportingTextDocument(text: record.markdownOnePager)
        isShowingMarkdownExporter = true
    }

    private func exportAsText(_ record: GovernanceReportRecord) {
        exportFilename = filenameBase(for: record)
        textDocument = ReportingTextDocument(text: record.plainTextOnePager)
        isShowingTextExporter = true
    }

    private func exportAsPDF(_ record: GovernanceReportRecord) {
        exportFilename = filenameBase(for: record)
        let pdfData = renderPDFData(from: record.plainTextOnePager)
        pdfDocument = ReportingBinaryDocument(data: pdfData)
        isShowingPDFExporter = true
    }

    private func filenameBase(for record: GovernanceReportRecord) -> String {
        let day = record.generatedReport.periodStart.formatted(.dateTime.year().month().day())
        return "samourai-\(record.generatedReport.cadence.rawValue)-\(day)"
    }

    private func renderPDFData(from text: String) -> Data {
        let pageRect = NSRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let textView = NSTextView(frame: pageRect)
        textView.string = text
        textView.font = SamouraiTypography.shared.nsFont(size: 11)
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 20, height: 20)
        return textView.dataWithPDF(inside: pageRect)
    }
}

private struct ReportingTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

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
