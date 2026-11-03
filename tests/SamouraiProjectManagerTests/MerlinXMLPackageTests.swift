import Foundation
import Testing
@testable import SamouraiProjectManagerApp

struct MerlinXMLPackageTests {
    @Test func packageMatchesLooseXMLAndPreservesRelations() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appending(path: "fixture.mprojectx", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let looseXML = root.appending(path: "fixture.xml")
        try Self.xml.write(to: looseXML, atomically: true, encoding: .utf8)
        try Self.xml.write(to: package.appending(path: "content.xml"), atomically: true, encoding: .utf8)
        // URL reconstructed from a selection may have no trailing directory slash.
        let selectedURL = URL(fileURLWithPath: package.path, isDirectory: false)
        let payload = try MerlinProjectImportService.importProject(from: selectedURL)
        let loose = try MerlinProjectImportService.importProject(from: looseXML)
        #expect(payload.project.id == "project-text-id")
        #expect(payload.project.title == loose.project.title)
        #expect(payload.project.globalFields == loose.project.globalFields)
        #expect(payload.resources.map(\.id) == ["resource-text-id"])
        #expect(payload.activities.map(\.id) == ["parent", "child"])
        #expect(payload.activities[1].parentID == "parent")
        #expect(payload.activities[1].predecessorIDs == ["parent"])
        #expect(payload.activities[1].assignments.first?.resourceID == "resource-text-id")
        #expect(payload.calendars.first?.id == "calendar")
        #expect(payload.resources.first?.baseCalendarID == "calendar")
        #expect(payload.customAttributes.first?.id == "attribute")
        #expect(payload.assignmentCount == loose.assignmentCount)
        #expect(payload.warnings == loose.warnings)
        #expect(payload.warnings.isEmpty)
    }

    @Test(arguments: ["", "<Invalid/>", "<Project><Activity id='same'/><Activity id='same'/></Project>"])
    func invalidPackageIsRejected(xml: String) throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appending(path: "invalid.mprojectx", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        try xml.write(to: package.appending(path: "content.xml"), atomically: true, encoding: .utf8)
        #expect(throws: MerlinProjectImportError.self) {
            try MerlinProjectImportService.importProject(from: package)
        }
        // The input is read-only, including rejected packages.
        #expect(try String(contentsOf: package.appending(path: "content.xml"), encoding: .utf8) == xml)
    }

    @Test func missingContentHasExplicitError() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appending(path: "missing.mprojectx", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        do {
            _ = try MerlinProjectImportService.importProject(from: package)
            Issue.record("Missing content.xml must be rejected")
        } catch let error as MerlinProjectImportError {
            #expect(error.errorDescription?.contains("content.xml") == true)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: package.path).isEmpty)
    }

    @Test(arguments: ["", " xmlns='urn:other'"])
    func namespaceRemainsPermissiveWithWarning(namespace: String) throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appending(path: "fixture.mprojectx", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "<Project\(namespace) id='P'><Activity id='A'/></Project>".write(
            to: package.appending(path: "content.xml"), atomically: true, encoding: .utf8)
        let payload = try MerlinProjectImportService.importProject(from: package)
        #expect(payload.activities.count == 1)
        #expect(payload.warnings.contains { $0.contains("Namespace XML") })
    }

    @Test @MainActor func packageImportsAndUpdatesExistingProjectOnTemporaryStore() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appending(path: "fixture.mprojectx", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Self.xml.write(to: package.appending(path: "content.xml"), atomically: true, encoding: .utf8)
        let payload = try await MerlinProjectImportService.importProjectInBackground(from: package)
        let file = root.appending(path: "store.json")
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: file, migrationSourceURL: nil))
        await store.loadIfNeeded()
        let first = try store.importMerlinProject(payload)
        #expect(first.createdProject)
        #expect(first.resourceCount == 1 && first.activityCount == 2)
        let second = try store.importMerlinProject(payload)
        #expect(!second.createdProject)
        #expect(second.projectID == first.projectID)
        #expect(store.projects.count == 1 && store.resources.count == 1)
        store.flushSynchronously()
        let reloaded = SamouraiStore(persistence: SamouraiPersistence(fileURL: file, migrationSourceURL: nil))
        await reloaded.loadIfNeeded()
        #expect(reloaded.projects.first?.id == first.projectID)
        #expect(reloaded.resources.count == 1)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "merlin-xml-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let xml = """
    <Project xmlns="http://schemas.projectwizards.net/merlin" id="project-text-id">
      <Dependency id="dep"><nextActivity idref="child"/><previousActivity idref="parent"/></Dependency>
      <CustomAttribute id="attribute"><title>Fixture</title><type value="string"/></CustomAttribute>
      <title>Projet synthétique</title><givenStartDateMin value="2026-01-01T00:00:00Z"/>
      <Activity id="parent"><title>Phase</title><Activity id="child"><title>Tâche</title>
        <Assignment id="assignment"><resource idref="resource-text-id"/></Assignment>
      </Activity></Activity>
      <Resource id="resource-text-id"><title>Ressource synthétique</title>
        <ResourceCalendar><baseCalendar idref="calendar"/></ResourceCalendar>
      </Resource>
      <BaseCalendar id="calendar"><title>Calendrier</title></BaseCalendar>
    </Project>
    """
}
