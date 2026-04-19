import Foundation

enum ResourceExportError: LocalizedError {
    case emptyDataset
    case unableToCreateTemporaryDirectory
    case unableToCreateArchive(String)
    case unableToReadArchive

    var errorDescription: String? {
        switch self {
        case .emptyDataset:
            "Aucune ressource à exporter."
        case .unableToCreateTemporaryDirectory:
            "Impossible de préparer le dossier temporaire d'export."
        case .unableToCreateArchive(let message):
            "Impossible de générer le fichier Excel : \(message)"
        case .unableToReadArchive:
            "Le fichier Excel exporté est introuvable."
        }
    }
}

enum ResourceExportService {
    static func makeXLSXData(resources: [Resource], projectNamesByID: [UUID: String]) throws -> Data {
        guard resources.isEmpty == false else {
            throw ResourceExportError.emptyDataset
        }

        let rows = buildRows(from: resources, projectNamesByID: projectNamesByID)
        let sheetXML = makeWorksheetXML(rows: rows)

        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appending(path: "samourai-export-\(UUID().uuidString)", directoryHint: .isDirectory)

        do {
            try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        } catch {
            throw ResourceExportError.unableToCreateTemporaryDirectory
        }

        defer {
            try? fileManager.removeItem(at: tempRoot)
        }

        let relsDir = tempRoot.appending(path: "_rels", directoryHint: .isDirectory)
        let xlDir = tempRoot.appending(path: "xl", directoryHint: .isDirectory)
        let xlRelsDir = xlDir.appending(path: "_rels", directoryHint: .isDirectory)
        let worksheetsDir = xlDir.appending(path: "worksheets", directoryHint: .isDirectory)
        let docPropsDir = tempRoot.appending(path: "docProps", directoryHint: .isDirectory)

        do {
            try fileManager.createDirectory(at: relsDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: xlDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: xlRelsDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: worksheetsDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: docPropsDir, withIntermediateDirectories: true)

            try write(contentTypesXML.data(using: .utf8), to: tempRoot.appending(path: "[Content_Types].xml"))
            try write(rootRelsXML.data(using: .utf8), to: relsDir.appending(path: ".rels"))
            try write(workbookXML.data(using: .utf8), to: xlDir.appending(path: "workbook.xml"))
            try write(workbookRelsXML.data(using: .utf8), to: xlRelsDir.appending(path: "workbook.xml.rels"))
            try write(sheetXML.data(using: .utf8), to: worksheetsDir.appending(path: "sheet1.xml"))
            try write(coreXML.data(using: .utf8), to: docPropsDir.appending(path: "core.xml"))
            try write(appXML.data(using: .utf8), to: docPropsDir.appending(path: "app.xml"))
        } catch {
            throw ResourceExportError.unableToCreateArchive(error.localizedDescription)
        }

        let archiveURL = fileManager.temporaryDirectory.appending(path: "samourai-resources-\(UUID().uuidString).xlsx")
        defer { try? fileManager.removeItem(at: archiveURL) }

        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.currentDirectoryURL = tempRoot
        zipProcess.arguments = ["-q", "-r", archiveURL.path(percentEncoded: false), "."]

        let errorPipe = Pipe()
        zipProcess.standardError = errorPipe

        do {
            try zipProcess.run()
            zipProcess.waitUntilExit()
        } catch {
            throw ResourceExportError.unableToCreateArchive(error.localizedDescription)
        }

        guard zipProcess.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Erreur zip inconnue."
            throw ResourceExportError.unableToCreateArchive(errorMessage)
        }

        guard let data = try? Data(contentsOf: archiveURL), data.isEmpty == false else {
            throw ResourceExportError.unableToReadArchive
        }

        return data
    }

    private static func buildRows(from resources: [Resource], projectNamesByID: [UUID: String]) -> [[String]] {
        let header = [
            "Nom",
            "Parent Description",
            "Primary Resource Role",
            "Resource Roles",
            "Organizational Resource",
            "Compétence 1",
            "Resource Calendar",
            "Resource Start Date",
            "Resource Finish Date",
            "Responsable Opérationnel",
            "Responsable Interne",
            "Localisation",
            "Type de Ressource",
            "Journée(s) temps partiel",
            "Projet(s)",
            "Engagement",
            "Statut",
            "Allocation (%)",
            "E-mail",
            "Téléphone",
            "Notes"
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var body: [[String]] = []
        body.reserveCapacity(resources.count)

        for resource in resources {
            let projectNames = resource.assignedProjectIDs.compactMap { projectNamesByID[$0] }
            let row = makeBodyRow(
                resource: resource,
                projectNames: projectNames,
                dateFormatter: dateFormatter
            )
            body.append(row)
        }

        return [header] + body
    }

    private static func makeBodyRow(resource: Resource, projectNames: [String], dateFormatter: DateFormatter) -> [String] {
        [
            resource.displayName,
            resource.parentDescription ?? "",
            resource.primaryResourceRole ?? "",
            resource.resourceRoles ?? "",
            resource.organizationalResource ?? "",
            resource.competence1 ?? "",
            resource.resourceCalendar ?? "",
            resource.resourceStartDate.map { dateFormatter.string(from: $0) } ?? "",
            resource.resourceFinishDate.map { dateFormatter.string(from: $0) } ?? "",
            resource.responsableOperationnel ?? "",
            resource.responsableInterne ?? "",
            resource.localisation ?? "",
            resource.typeDeRessource ?? "",
            resource.journeesTempsPartiel ?? "",
            projectNames.joined(separator: ", "),
            resource.engagement.label,
            resource.status.label,
            "\(resource.allocationPercent)",
            resource.email,
            resource.phone,
            resource.notes
        ]
    }

    private static func makeWorksheetXML(rows: [[String]]) -> String {
        let xmlRows = rows.enumerated().map { rowOffset, rowValues in
            let rowNumber = rowOffset + 1
            let cells = rowValues.enumerated().map { columnOffset, value in
                let reference = "\(columnName(for: columnOffset + 1))\(rowNumber)"
                return "<c r=\"\(reference)\" t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
            }.joined()
            return "<row r=\"\(rowNumber)\">\(cells)</row>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>\(xmlRows)</sheetData>
        </worksheet>
        """
    }

    private static func columnName(for index: Int) -> String {
        var current = index
        var name = ""

        while current > 0 {
            let remainder = (current - 1) % 26
            guard let scalar = UnicodeScalar(65 + remainder) else { break }
            name = "\(Character(scalar))" + name
            current = (current - 1) / 26
        }

        return name
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func write(_ data: Data?, to url: URL) throws {
        guard let data else { throw ResourceExportError.unableToCreateArchive("Contenu vide pour \(url.lastPathComponent).") }
        try data.write(to: url, options: [.atomic])
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
      <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
    </Types>
    """

    private static let rootRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
              xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Resources" sheetId="1" r:id="rId1"/>
      </sheets>
    </workbook>
    """

    private static let workbookRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    </Relationships>
    """

    private static let coreXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                       xmlns:dc="http://purl.org/dc/elements/1.1/"
                       xmlns:dcterms="http://purl.org/dc/terms/"
                       xmlns:dcmitype="http://purl.org/dc/dcmitype/"
                       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <dc:creator>Samourai Project Manager</dc:creator>
      <cp:lastModifiedBy>Samourai Project Manager</cp:lastModifiedBy>
    </cp:coreProperties>
    """

    private static let appXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
                xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
      <Application>Samourai Project Manager</Application>
    </Properties>
    """
}
