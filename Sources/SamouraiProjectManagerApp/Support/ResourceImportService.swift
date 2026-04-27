import Foundation

enum ResourceImportService {
    static func importResources(from fileURL: URL) throws -> [ResourceImportDraft] {
        try importResources(from: fileURL, reporter: .noop)
    }

    static func importResources(
        from fileURL: URL,
        reporter: ImportProgressReporter
    ) throws -> [ResourceImportDraft] {
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
            throw ResourceImportError.unsupportedFileType
        }
    }

    private static func importXLSX(
        from fileURL: URL,
        reporter: ImportProgressReporter
    ) throws -> [ResourceImportDraft] {
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
    ) throws -> [ResourceImportDraft] {
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
    ) throws -> [ResourceImportDraft] {
        guard let headerRow = rows.first else {
            throw ResourceImportError.emptyFile
        }

        let headerMap = buildHeaderMap(from: headerRow)
        let hasCombinedName = headerMap[.nom] != nil
        let hasSplitName = headerMap[.prenom] != nil && headerMap[.nomDeFamille] != nil
        guard hasCombinedName || hasSplitName else {
            throw ResourceImportError.missingRequiredColumn("Nom ou couple Prénom/Nom")
        }

        let dataRows = Array(rows.dropFirst())
        reporter.setTotal(dataRows.count)
        reporter.setProcessed(0)
        reporter.setImported(0)

        var drafts: [ResourceImportDraft] = []
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
        headerMap: [ResourceSpreadsheetColumn: Int]
    ) -> ResourceImportDraft? {
        let values = Dictionary(uniqueKeysWithValues: headerMap.map { column, index in
            (column, row.cellsByColumnIndex[index]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        })

        guard values.values.contains(where: { $0.isEmpty == false }) else {
            return nil
        }

        let firstName = optionalString(values[.prenom, default: ""])
        let lastName = optionalString(values[.nomDeFamille, default: ""])
        let fullName = optionalString(values[.nom, default: ""])
            ?? combinedName(firstName: firstName, lastName: lastName)

        guard fullName?.isEmpty == false else {
            return ResourceImportDraft(
                nom: nil,
                prenom: nil,
                nomDeFamille: nil,
                parentDescription: nil,
                primaryResourceRole: nil,
                resourceRoles: nil,
                organizationalResource: nil,
                competence1: nil,
                resourceCalendar: nil,
                resourceStartDate: nil,
                resourceFinishDate: nil,
                responsableOperationnel: nil,
                responsableInterne: nil,
                localisation: nil,
                typeDeRessource: nil,
                journeesTempsPartiel: nil,
                email: nil,
                phone: nil,
                engagement: .internalEmployee,
                status: .active,
                allocationPercent: 100,
                notes: "",
                sourceRowNumber: row.rowNumber
            )
        }

        let partTimeDays = values[.partTimeDays, default: ""]
        let finishDate = values[.resourceFinishDate, default: ""]
        let startDate = values[.resourceStartDate, default: ""]

        return ResourceImportDraft(
            nom: fullName,
            prenom: firstName,
            nomDeFamille: lastName,
            parentDescription: optionalString(values[.parentDescription, default: ""]),
            primaryResourceRole: optionalString(values[.primaryResourceRole, default: ""]),
            resourceRoles: optionalString(values[.resourceRoles, default: ""]),
            organizationalResource: optionalString(values[.organizationalResource, default: ""]),
            competence1: optionalString(values[.competency1, default: ""]),
            resourceCalendar: optionalString(values[.resourceCalendar, default: ""]),
            resourceStartDate: parseDateString(startDate),
            resourceFinishDate: parseDateString(finishDate),
            responsableOperationnel: optionalString(values[.operationalManager, default: ""]),
            responsableInterne: optionalString(values[.internalManager, default: ""]),
            localisation: optionalString(values[.location, default: ""]),
            typeDeRessource: optionalString(values[.resourceType, default: ""]),
            journeesTempsPartiel: optionalString(partTimeDays),
            email: optionalString(values[.email, default: ""]),
            phone: optionalString(values[.phone, default: ""]),
            engagement: mapEngagement(from: values[.resourceType, default: ""]),
            status: mapStatus(finishDate: finishDate, partTimeDays: partTimeDays),
            allocationPercent: mapAllocationPercent(from: partTimeDays),
            notes: "",
            sourceRowNumber: row.rowNumber
        )
    }

    private static func buildHeaderMap(from headerRow: ParsedSpreadsheetRow) -> [ResourceSpreadsheetColumn: Int] {
        var mapping: [ResourceSpreadsheetColumn: Int] = [:]

        for (index, rawHeader) in headerRow.cellsByColumnIndex {
            let normalized = normalizeHeader(rawHeader)
            if let column = ResourceSpreadsheetColumn.headerAliases[normalized] {
                mapping[column] = index
            }
        }

        return mapping
    }

    private static func mapEngagement(from rawValue: String) -> ResourceEngagement {
        let normalized = normalizeHeader(rawValue)

        if normalized.contains("freelance") || normalized.contains("contractor") {
            return .freelancer
        }

        if normalized.contains("prestataire") || normalized.contains("consult") || normalized.contains("external") {
            return .externalConsultant
        }

        return .internalEmployee
    }

    private static func mapStatus(finishDate: String, partTimeDays: String) -> ResourceStatus {
        if let finishDateValue = parseDateString(finishDate), finishDateValue < Calendar.current.startOfDay(for: .now) {
            return .offboarded
        }

        if mapAllocationPercent(from: partTimeDays) < 100 {
            return .partiallyAvailable
        }

        return .active
    }

    private static func mapAllocationPercent(from rawValue: String) -> Int {
        let cleaned = rawValue
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")

        guard let numericValue = Double(cleaned), numericValue.isFinite else {
            return 100
        }

        if numericValue > 5 {
            return min(max(Int(numericValue.rounded()), 0), 100)
        }

        let allocation = ((5.0 - numericValue) / 5.0) * 100.0
        let rounded = Int((allocation / 5.0).rounded() * 5.0)
        return min(max(rounded, 0), 100)
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

    private static func combinedName(firstName: String?, lastName: String?) -> String? {
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard parts.isEmpty == false else { return nil }
        return parts.joined(separator: " ")
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
            throw ResourceImportError.invalidWorkbook(AppLocalizer.localizedFormat("Entrée Excel introuvable: %@", entryPath))
        }

        return data
    }

    private static func unzipEntryIfAvailable(at archiveURL: URL, entryPath: String) throws -> Data? {
        // Écriture dans un fichier temporaire : évite tout deadlock de buffer pipe
        // quelle que soit la taille de l'entrée (sheet1.xml peut dépasser plusieurs Mo).
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path(percentEncoded: false), entryPath]

        let stdoutHandle = try FileHandle(forWritingTo: tmpURL)
        let errorPipe = Pipe()
        process.standardOutput = stdoutHandle
        process.standardError = errorPipe

        try process.run()

        if Task.isCancelled { process.terminate() }
        process.waitUntilExit()
        stdoutHandle.closeFile()

        try Task.checkCancellation()

        if process.terminationStatus == 0 {
            let data = (try? Data(contentsOf: tmpURL)) ?? Data()
            return data.isEmpty ? nil : data
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
        if errorMessage.localizedCaseInsensitiveContains("filename not matched") {
            return nil
        }

        throw ResourceImportError.invalidWorkbook(
            errorMessage.isEmpty
                ? AppLocalizer.localized("Impossible de lire le fichier Excel.")
                : errorMessage
        )
    }
}

struct ParsedSpreadsheetRow {
    let rowNumber: Int
    let cellsByColumnIndex: [Int: String]
}

private enum ResourceSpreadsheetColumn: CaseIterable {
    case nom
    case prenom
    case nomDeFamille
    case parentDescription
    case primaryResourceRole
    case resourceRoles
    case organizationalResource
    case competency1
    case resourceCalendar
    case resourceStartDate
    case resourceFinishDate
    case operationalManager
    case internalManager
    case location
    case resourceType
    case partTimeDays
    case email
    case phone

    static let headerAliases: [String: ResourceSpreadsheetColumn] = [
        "nom": .nom,
        "prenom": .prenom,
        "prenom usuel": .prenom,
        "first name": .prenom,
        "nom de famille": .nomDeFamille,
        "lastname": .nomDeFamille,
        "last name": .nomDeFamille,
        "surname": .nomDeFamille,
        "parent description": .parentDescription,
        "primary resource role": .primaryResourceRole,
        "resource roles": .resourceRoles,
        "organizational resource": .organizationalResource,
        "competence 1": .competency1,
        "resource calendar": .resourceCalendar,
        "resource start date": .resourceStartDate,
        "resource finish date": .resourceFinishDate,
        "responsable operationnel": .operationalManager,
        "responsable interne": .internalManager,
        "localisation": .location,
        "type de ressource": .resourceType,
        "journee(s) temps partiel": .partTimeDays,
        "journees temps partiel": .partTimeDays,
        "email": .email,
        "e-mail": .email,
        "mail": .email,
        "telephone": .phone,
        "phone": .phone,
        "mobile": .phone
    ]

    var label: String {
        switch self {
        case .nom:
            "Nom"
        case .prenom:
            "Prénom"
        case .nomDeFamille:
            "Nom de famille"
        case .parentDescription:
            "Parent Description"
        case .primaryResourceRole:
            "Primary Resource Role"
        case .resourceRoles:
            "Resource Roles"
        case .organizationalResource:
            "Organizational Resource"
        case .competency1:
            "Compétence 1"
        case .resourceCalendar:
            "Resource Calendar"
        case .resourceStartDate:
            "Resource Start Date"
        case .resourceFinishDate:
            "Resource Finish Date"
        case .operationalManager:
            "Responsable Opérationnel"
        case .internalManager:
            "Responsable Interne"
        case .location:
            "Localisation"
        case .resourceType:
            "Type de Ressource"
        case .partTimeDays:
            "Journée(s) temps partiel"
        case .email:
            "E-mail"
        case .phone:
            "Téléphone"
        }
    }
}

enum ResourceImportError: LocalizedError {
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

enum SharedStringsParser {
    static func parse(_ data: Data) throws -> [String] {
        let delegate = SharedStringsXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw ResourceImportError.invalidWorkbook(parser.parserError?.localizedDescription ?? "sharedStrings.xml illisible.")
        }

        return delegate.values
    }
}

final class SharedStringsXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var values: [String] = []
    private var isInsideStringItem = false
    private var isCapturingText = false
    private var currentValue = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "si" {
            isInsideStringItem = true
            currentValue = ""
        } else if isInsideStringItem, elementName == "t" {
            isCapturingText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isCapturingText {
            currentValue.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            isCapturingText = false
        } else if elementName == "si" {
            values.append(currentValue)
            currentValue = ""
            isInsideStringItem = false
        }
    }
}

enum StylesParser {
    static func parseDateFormattedStyleIndexes(_ data: Data) throws -> Set<Int> {
        let delegate = StylesXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw ResourceImportError.invalidWorkbook(parser.parserError?.localizedDescription ?? "styles.xml illisible.")
        }

        return delegate.dateFormattedStyleIndexes
    }
}

final class StylesXMLDelegate: NSObject, XMLParserDelegate {
    private var customFormatCodes: [Int: String] = [:]
    private(set) var dateFormattedStyleIndexes: Set<Int> = []
    private var isInsideCellXfs = false
    private var xfIndex = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "numFmt":
            if let idString = attributeDict["numFmtId"],
               let id = Int(idString) {
                customFormatCodes[id] = attributeDict["formatCode"] ?? ""
            }
        case "cellXfs":
            isInsideCellXfs = true
            xfIndex = 0
        case "xf":
            guard isInsideCellXfs else { return }
            if let numFmtIdString = attributeDict["numFmtId"],
               let numFmtId = Int(numFmtIdString),
               isDateFormat(numFmtId: numFmtId, customCode: customFormatCodes[numFmtId]) {
                dateFormattedStyleIndexes.insert(xfIndex)
            }
            xfIndex += 1
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "cellXfs" {
            isInsideCellXfs = false
        }
    }

    private func isDateFormat(numFmtId: Int, customCode: String?) -> Bool {
        let builtInDateFormats: Set<Int> = [14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47]
        if builtInDateFormats.contains(numFmtId) {
            return true
        }

        guard let customCode, customCode.isEmpty == false else {
            return false
        }

        let normalized = customCode.lowercased()
        return normalized.contains("yy")
            || normalized.contains("dd")
            || normalized.contains("mm/")
            || normalized.contains("/mm")
            || normalized.contains("hh")
    }
}

enum WorksheetParser {
    static func parse(
        _ data: Data,
        sharedStrings: [String],
        dateFormattedStyleIndexes: Set<Int>
    ) throws -> [ParsedSpreadsheetRow] {
        let delegate = WorksheetXMLDelegate(
            sharedStrings: sharedStrings,
            dateFormattedStyleIndexes: dateFormattedStyleIndexes
        )
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw ResourceImportError.invalidWorkbook(parser.parserError?.localizedDescription ?? "sheet1.xml illisible.")
        }

        return delegate.rows
    }
}

final class WorksheetXMLDelegate: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private let dateFormattedStyleIndexes: Set<Int>

    private(set) var rows: [ParsedSpreadsheetRow] = []

    private var currentRowNumber = 0
    private var currentRowCells: [Int: String] = [:]
    private var currentColumnIndex: Int?
    private var currentCellType = ""
    private var currentCellStyleIndex: Int?
    private var currentCellValue = ""
    private var isCapturingValue = false

    init(sharedStrings: [String], dateFormattedStyleIndexes: Set<Int>) {
        self.sharedStrings = sharedStrings
        self.dateFormattedStyleIndexes = dateFormattedStyleIndexes
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "row":
            currentRowNumber = Int(attributeDict["r"] ?? "") ?? (rows.count + 1)
            currentRowCells = [:]
        case "c":
            currentColumnIndex = columnIndex(from: attributeDict["r"] ?? "")
            currentCellType = attributeDict["t"] ?? ""
            currentCellStyleIndex = Int(attributeDict["s"] ?? "")
            currentCellValue = ""
        case "v", "t":
            guard currentColumnIndex != nil else { return }
            isCapturingValue = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isCapturingValue {
            currentCellValue.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t":
            isCapturingValue = false
        case "c":
            if let currentColumnIndex {
                currentRowCells[currentColumnIndex] = resolvedCellValue()
            }

            currentColumnIndex = nil
            currentCellType = ""
            currentCellStyleIndex = nil
            currentCellValue = ""
        case "row":
            rows.append(ParsedSpreadsheetRow(rowNumber: currentRowNumber, cellsByColumnIndex: currentRowCells))
        default:
            break
        }
    }

    private func resolvedCellValue() -> String {
        let rawValue = currentCellValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard rawValue.isEmpty == false else {
            return ""
        }

        switch currentCellType {
        case "s":
            if let index = Int(rawValue), sharedStrings.indices.contains(index) {
                return sharedStrings[index]
            }
            return rawValue
        case "inlineStr", "str":
            return rawValue
        default:
            if let currentCellStyleIndex,
               dateFormattedStyleIndexes.contains(currentCellStyleIndex),
               let serial = Double(rawValue) {
                return excelDateString(from: serial)
            }
            return rawValue
        }
    }

    private func columnIndex(from reference: String) -> Int? {
        let letters = reference.prefix { $0.isLetter }.uppercased()
        guard letters.isEmpty == false else { return nil }

        var index = 0
        for scalar in letters.unicodeScalars {
            let scalarValue = Int(scalar.value)
            guard (65...90).contains(scalarValue) else { return nil }
            index = (index * 26) + (scalarValue - 64)
        }

        return index
    }

    private func excelDateString(from serial: Double) -> String {
        let seconds = (serial - 25569.0) * 86400.0
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
