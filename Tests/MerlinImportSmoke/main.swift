import Foundation

enum ImportProgressStage: String, Sendable {
    case reading
    case parsing
    case analyzing
    case importing
    case finalizing
}

struct ImportProgressReporter: Sendable {
    let setStage: @Sendable (ImportProgressStage) -> Void
    let setTotal: @Sendable (Int) -> Void
    let setProcessed: @Sendable (Int) -> Void
    let setImported: @Sendable (Int) -> Void

    static let noop = ImportProgressReporter(
        setStage: { _ in },
        setTotal: { _ in },
        setProcessed: { _ in },
        setImported: { _ in }
    )
}

extension Array where Element: Hashable {
    func removingDuplicateValues() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        return true
    }
    fatalError("Smoke test failed: \(message)")
}

func temporaryFile(extension fileExtension: String, contents: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "samourai-merlin-smoke-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: "fixture.\(fileExtension)")
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

let xmlWithoutProjectID = try temporaryFile(
    extension: "xml",
    contents:
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Project xmlns="http://schemas.projectwizards.net/merlin">
      <title>Projet sans ID</title>
      <Resource id="R1">
        <title>Ressource 1</title>
      </Resource>
      <Activity id="A1">
        <title>Phase 1</title>
        <Activity id="A2">
          <title>Activité 2</title>
          <Assignment id="AS1">
            <resource idref="R1"/>
          </Assignment>
        </Activity>
      </Activity>
      <Dependency id="D1">
        <type value="endToStart"/>
        <previousActivity idref="A1"/>
        <nextActivity idref="A2"/>
      </Dependency>
    </Project>
    """
)

let firstPayload = try MerlinProjectImportService.importProject(from: xmlWithoutProjectID)
let secondPayload = try MerlinProjectImportService.importProject(from: xmlWithoutProjectID)

expect(firstPayload.project.title == "Projet sans ID", "title should be readable")
expect(firstPayload.project.id.hasPrefix("xml-project-"), "missing Project@id should use fallback id")
expect(firstPayload.project.id == secondPayload.project.id, "fallback project id should be stable")
expect(firstPayload.resources.count == 1, "resource should import")
expect(firstPayload.activities.count == 2, "nested activities should import")
expect(firstPayload.assignmentCount == 1, "assignment should import")
expect(firstPayload.dependencies.count == 1, "dependency should import")
expect(firstPayload.activities.first { $0.id == "A2" }?.parentID == "A1", "activity hierarchy should be preserved")
expect(firstPayload.activities.first { $0.id == "A2" }?.predecessorIDs == ["A1"], "dependency should resolve as predecessor")
expect(firstPayload.warnings.contains { $0.contains("Project@id absent") }, "missing id warning should be reported")

let unexpectedNamespaceXML = try temporaryFile(
    extension: "xml",
    contents:
    """
    <Project xmlns="urn:not-merlin" id="P1">
      <title>Projet namespace souple</title>
      <Activity id="A1"><title>Tache</title></Activity>
    </Project>
    """
)
let namespacePayload = try MerlinProjectImportService.importProject(from: unexpectedNamespaceXML)
expect(namespacePayload.project.id == "P1", "explicit Project@id should be kept")
expect(namespacePayload.activities.count == 1, "unexpected namespace should not block import")
expect(namespacePayload.warnings.contains { $0.contains("Namespace XML différent") }, "unexpected namespace should warn")

let unsupportedFile = try temporaryFile(extension: "txt", contents: "not xml")
do {
    _ = try MerlinProjectImportService.importProject(from: unsupportedFile)
    fatalError("Smoke test failed: unsupported file extension should throw")
} catch let error as MerlinProjectImportError {
    expect(error.errorDescription == "Le fichier importé doit être un fichier XML.", "unsupported extension error should be explicit")
}

print("Merlin import smoke tests passed.")
