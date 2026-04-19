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
        HStack(spacing: 0) {
            archiveSidebar
            Divider()
            reportDetailPane
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Weekly Governance")
                    .font(.title2.weight(.semibold))
                Text("One-Click Generator + Archive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

            Button("Générer le rapport (One-Click)") {
                generateOneClickReport()
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text("Historique")
                .font(.headline)

            if filteredArchive.isEmpty {
                ContentUnavailableView(
                    "Aucun rapport",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Génère un premier rapport pour activer l'archivage.")
                )
            } else {
                List(selection: $selectedReportID) {
                    ForEach(filteredArchive) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.generatedReport.cadence.label)
                                .font(.subheadline.weight(.semibold))
                            Text(record.generatedReport.periodLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(record.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .frame(minWidth: 320, idealWidth: 340, maxWidth: 380, maxHeight: .infinity, alignment: .topLeading)
    }

    private var reportDetailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let record = selectedRecord {
                    HStack {
                        Text("Rapport de Gouvernance")
                            .font(.largeTitle.weight(.semibold))
                        Spacer()
                        Button("Enregistrer modifications") {
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

                    sectionCard(title: "1) En-tête & Contexte") {
                        Text("Période couverte: \(record.periodLabel)")
                        Text("Projets concernés: \(record.projectsLabel)")
                        Text("Généré le: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }

                    sectionCard(title: "2) Résumé Exécutif") {
                        ForEach(record.executiveHighlightsAuto.prefix(4), id: \.self) { line in
                            Text("• \(line)")
                        }
                        Divider()
                        Text("Affinage PM (éditable)")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $executiveSummaryPMDraft)
                            .font(.body)
                            .frame(minHeight: 70, maxHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    }

                    sectionCard(title: "3) Accomplissements (Done)") {
                        if record.generatedReport.accomplishments.isEmpty {
                            Text("Aucun accomplissement détecté automatiquement.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.generatedReport.accomplishments.prefix(8), id: \.self) { line in
                                Text("• \(line)")
                            }
                        }
                    }

                    sectionCard(title: "4) Avancement des Tests") {
                        ForEach(record.testsProgressAutoLines, id: \.self) { line in
                            Text("• \(line)")
                        }
                    }

                    sectionCard(title: "5) Risques, Problèmes & Blocages") {
                        ForEach(record.risksAndBlocksAutoLines.prefix(8), id: \.self) { line in
                            Text("• \(line)")
                        }
                    }

                    sectionCard(title: "6) Planification Prochaine") {
                        if record.nextPlanningAutoLines.isEmpty {
                            Text("Aucun jalon/livrable/action à court terme détecté.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(record.nextPlanningAutoLines.prefix(8), id: \.self) { line in
                                Text("• \(line)")
                            }
                        }
                        Divider()
                        Text("Actions spécifiques attendues de l'équipe (éditable)")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $planningActionsPMDraft)
                            .font(.body)
                            .frame(minHeight: 70, maxHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    }

                    sectionCard(title: "7) Conclusion & Actions Requises") {
                        TextEditor(text: $conclusionPMDraft)
                            .font(.body)
                            .frame(minHeight: 70, maxHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    }
                } else {
                    ContentUnavailableView(
                        "Aucun rapport sélectionné",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Génère un rapport en un clic ou sélectionne un rapport archivé.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        textView.font = NSFont.systemFont(ofSize: 11)
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
