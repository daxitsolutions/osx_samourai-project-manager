import Foundation

enum RiskImportService {
    static func importRisks(from fileURL: URL) throws -> [RiskImportDraft] {
        try importRisks(from: fileURL, reporter: .noop)
    }

    static func importRisks(
        from fileURL: URL,
        reporter: ImportProgressReporter
    ) throws -> [RiskImportDraft] {
        reporter.setStage(.reading)
        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "xlsx":
            return try importXLSX(from: fileURL, reporter: reporter)
        case "csv":
            return try importDelimitedText(from: fileURL, separator: ",", reporter: reporter)
        case "tsv", "txt":
            return try importDelimitedText(from: fileURL, separator: "\t", reporter: reporter)
        default:
            throw RiskImportError.unsupportedFileType
        }
    }

    private static func importXLSX(
        from fileURL: URL,
        reporter: ImportProgressReporter
    ) throws -> [RiskImportDraft] {
        let sharedStringsData = try unzipEntryIfAvailable(at: fileURL, entryPath: "xl/sharedStrings.xml")
        let stylesData = try unzipEntryIfAvailable(at: fileURL, entryPath: "xl/styles.xml")
        let worksheetData = try unzipEntry(at: fileURL, entryPath: "xl/worksheets/sheet1.xml")

        try Task.checkCancellation()
        reporter.setStage(.parsing)

        let sharedStrings = try sharedStringsData.map(SharedStringsParser.parse) ?? []
        let dateFormattedStyleIndexes = try stylesData.map(StylesParser.parseDateFormattedStyleIndexes) ?? []
        let rows = try WorksheetParser.parse(
            worksheetData,
            sharedStrings: sharedStrings,
            dateFormattedStyleIndexes: dateFormattedStyleIndexes
        )

        return try makeDrafts(from: rows, reporter: reporter)
    }

    private static func importDelimitedText(
        from fileURL: URL,
        separator: Character,
        reporter: ImportProgressReporter
    ) throws -> [RiskImportDraft] {
        let rawText = try String(contentsOf: fileURL, encoding: .utf8)

        try Task.checkCancellation()
        reporter.setStage(.parsing)

        let rows = rawText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .enumerated()
            .map { offset, line in
                ParsedSpreadsheetRow(
                    rowNumber: offset + 1,
                    cellsByColumnIndex: Dictionary(
                        uniqueKeysWithValues: line
                            .split(separator: separator, omittingEmptySubsequences: false)
                            .map(String.init)
                            .enumerated()
                            .map { ($0.offset + 1, $0.element) }
                    )
                )
            }

        return try makeDrafts(from: rows, reporter: reporter)
    }

    private static func makeDrafts(
        from rows: [ParsedSpreadsheetRow],
        reporter: ImportProgressReporter
    ) throws -> [RiskImportDraft] {
        guard let headerRow = rows.first else {
            throw RiskImportError.emptyFile
        }

        let headerMap = buildHeaderMap(from: headerRow)
        guard headerMap[.riskTitle] != nil || headerMap[.externalID] != nil else {
            throw RiskImportError.missingRequiredColumn("Titre du risque ou ID")
        }

        let dataRows = Array(rows.dropFirst())
        reporter.setTotal(dataRows.count)
        reporter.setProcessed(0)
        reporter.setImported(0)

        var drafts: [RiskImportDraft] = []
        drafts.reserveCapacity(dataRows.count)

        for (index, row) in dataRows.enumerated() {
            try Task.checkCancellation()

            if let draft = makeDraft(from: row, headerMap: headerMap) {
                drafts.append(draft)
            }

            reporter.setProcessed(index + 1)
        }

        return drafts
    }

    private static func makeDraft(
        from row: ParsedSpreadsheetRow,
        headerMap: [RiskSpreadsheetColumn: Int]
    ) -> RiskImportDraft? {
        let values = Dictionary(uniqueKeysWithValues: headerMap.map { column, index in
            (column, row.cellsByColumnIndex[index]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        })

        guard values.values.contains(where: { $0.isEmpty == false }) else {
            return nil
        }

        let riskTitle = optionalString(values[.riskTitle, default: ""])
        let externalID = optionalString(values[.externalID, default: ""])
        guard riskTitle != nil || externalID != nil else {
            return nil
        }

        return RiskImportDraft(
            externalID: externalID,
            projectNames: optionalString(values[.projects, default: ""]),
            detectedBy: optionalString(values[.detectedBy, default: ""]),
            assignedTo: optionalString(values[.assignedTo, default: ""]),
            dateCreated: parseDateString(values[.dateCreated, default: ""]),
            lastModifiedAt: parseDateString(values[.lastModified, default: ""]),
            riskType: optionalString(values[.riskType, default: ""]),
            response: optionalString(values[.response, default: ""]),
            riskTitle: riskTitle,
            riskOrigin: optionalString(values[.riskOrigin, default: ""]),
            impactDescription: optionalString(values[.impactDescription, default: ""]),
            counterMeasure: optionalString(values[.counterMeasure, default: ""]),
            followUpComment: optionalString(values[.followUpComment, default: ""]),
            proximity: optionalString(values[.proximity, default: ""]),
            probability: optionalString(values[.probability, default: ""]),
            impactScope: optionalString(values[.impactScope, default: ""]),
            impactBudget: optionalString(values[.impactBudget, default: ""]),
            impactPlanning: optionalString(values[.impactPlanning, default: ""]),
            impactResources: optionalString(values[.impactResources, default: ""]),
            impactTransition: optionalString(values[.impactTransition, default: ""]),
            impactSecurityIT: optionalString(values[.impactSecurityIT, default: ""]),
            escalationLevel: optionalString(values[.escalationLevel, default: ""]),
            riskStatus: optionalString(values[.riskStatus, default: ""]),
            score0to10: parseScore(values[.score0to10, default: ""]),
            sourceRowNumber: row.rowNumber
        )
    }

    private static func buildHeaderMap(from headerRow: ParsedSpreadsheetRow) -> [RiskSpreadsheetColumn: Int] {
        var mapping: [RiskSpreadsheetColumn: Int] = [:]

        for (index, rawHeader) in headerRow.cellsByColumnIndex {
            let normalized = normalizeHeader(rawHeader)
            if let column = RiskSpreadsheetColumn.headerAliases[normalized] {
                mapping[column] = index
            }
        }

        return mapping
    }

    private static func parseDateString(_ rawValue: String) -> Date? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return nil }

        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func parseScore(_ rawValue: String) -> Double? {
        let cleaned = rawValue.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let score = Double(cleaned), score.isFinite else { return nil }
        return min(max(score, 0), 10)
    }

    private static func optionalString(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizeHeader(_ rawValue: String) -> String {
        rawValue
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unzipEntry(at archiveURL: URL, entryPath: String) throws -> Data {
        guard let data = try unzipEntryIfAvailable(at: archiveURL, entryPath: entryPath) else {
            throw RiskImportError.invalidWorkbook(AppLocalizer.localizedFormat("Entrée Excel introuvable: %@", entryPath))
        }
        return data
    }

    private static func unzipEntryIfAvailable(at archiveURL: URL, entryPath: String) throws -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path(percentEncoded: false), entryPath]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus == 0 {
            return data.isEmpty ? nil : data
        }

        let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
        if errorMessage.localizedCaseInsensitiveContains("filename not matched") {
            return nil
        }

        throw RiskImportError.invalidWorkbook(errorMessage.isEmpty ? AppLocalizer.localized("Impossible de lire le fichier Excel.") : errorMessage)
    }
}

private enum RiskSpreadsheetColumn: CaseIterable {
    case externalID
    case projects
    case detectedBy
    case assignedTo
    case dateCreated
    case lastModified
    case riskType
    case response
    case riskTitle
    case riskOrigin
    case impactDescription
    case counterMeasure
    case followUpComment
    case proximity
    case probability
    case impactScope
    case impactBudget
    case impactPlanning
    case impactResources
    case impactTransition
    case impactSecurityIT
    case escalationLevel
    case riskStatus
    case score0to10

    static let headerAliases: [String: RiskSpreadsheetColumn] = [
        "id": .externalID,
        "projet(s)": .projects,
        "projets": .projects,
        "detecte par": .detectedBy,
        "assigne a": .assignedTo,
        "date de creation": .dateCreated,
        "derniere modification": .lastModified,
        "type de risque": .riskType,
        "reponse": .response,
        "titre du risque": .riskTitle,
        "origine du risque": .riskOrigin,
        "description de l'impact": .impactDescription,
        "contre-mesure": .counterMeasure,
        "contre mesure": .counterMeasure,
        "commentaire / suivi": .followUpComment,
        "commentaire suivi": .followUpComment,
        "proximite": .proximity,
        "probabilite": .probability,
        "impact perimetre": .impactScope,
        "impact budget": .impactBudget,
        "impact planning": .impactPlanning,
        "impact ressources": .impactResources,
        "impact transition": .impactTransition,
        "impact securite it": .impactSecurityIT,
        "niveau d'escalation": .escalationLevel,
        "statut": .riskStatus,
        "score 0 a 10": .score0to10
    ]
}

enum RiskImportError: LocalizedError {
    case unsupportedFileType
    case emptyFile
    case missingRequiredColumn(String)
    case invalidWorkbook(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            AppLocalizer.localized("Type de fichier non supporté. Utilise un fichier Excel .xlsx, .csv ou .tsv.")
        case .emptyFile:
            AppLocalizer.localized("Le fichier importé est vide.")
        case .missingRequiredColumn(let column):
            AppLocalizer.localizedFormat("Colonne obligatoire absente : %@.", column)
        case .invalidWorkbook(let message):
            AppLocalizer.localizedFormat("Fichier Excel invalide : %@", message)
        }
    }
}
