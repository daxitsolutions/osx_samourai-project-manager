import Foundation
import Synchronization
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #55 : lecture et analyse Merlin hors du MainActor, annulables pendant l'analyse.
@MainActor
struct MerlinBackgroundImportTests {
    @Test func xmlParsingRunsOffMainThread() async throws {
        let url = try fixture(activityCount: 50)
        let stagesOnMain = Mutex<[Bool]>([])
        let reporter = recordingReporter { _ in stagesOnMain.withLock { $0.append(pthread_main_np() != 0) } }

        let payload = try await MerlinProjectImportService.importProjectInBackground(from: url, reporter: reporter)

        #expect(payload.activities.count == 50)
        let recorded = stagesOnMain.withLock { $0 }
        #expect(recorded.count == 3)
        #expect(recorded.allSatisfy { $0 == false })
    }

    @Test func nativePackageBranchRunsOffMainThread() async throws {
        let package = FileManager.default.temporaryDirectory
            .appending(path: "samourai-merlin-\(UUID().uuidString).mproject", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        let stagesOnMain = Mutex<[Bool]>([])
        let reporter = recordingReporter { _ in stagesOnMain.withLock { $0.append(pthread_main_np() != 0) } }

        await #expect(throws: MerlinProjectImportError.self) {
            try await MerlinProjectImportService.importProjectInBackground(from: package, reporter: reporter)
        }
        #expect(stagesOnMain.withLock { $0 } == [false])
    }

    @Test(arguments: [ImportProgressStage.parsing, .analyzing])
    func cancellationDuringParsingStopsImport(at stage: ImportProgressStage) async throws {
        let url = try fixture(activityCount: 200)
        let reporter = recordingReporter { current in
            if current == stage { withUnsafeCurrentTask { $0?.cancel() } }
        }

        let task = Task { try await MerlinProjectImportService.importProjectInBackground(from: url, reporter: reporter) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func backgroundResultMatchesSynchronousParsing() async throws {
        let url = try fixture(activityCount: 5_000)
        let clock = ContinuousClock()
        let start = clock.now
        let background = try await MerlinProjectImportService.importProjectInBackground(from: url)
        let elapsed = clock.now - start
        // Référence synchrone calculée hors MainActor pour ne pas fausser le test de réactivité parallèle.
        let synchronous = try await Task.detached { try MerlinProjectImportService.importProject(from: url) }.value

        #expect(background.activities.map(\.id) == synchronous.activities.map(\.id))
        #expect(background.resources.map(\.id) == synchronous.resources.map(\.id))
        #expect(background.dependencies.count == synchronous.dependencies.count)
        print("[#55] 5000 activités analysées hors MainActor en \(elapsed)")
    }

    @Test func mainActorStaysResponsiveDuringLargeImport() async throws {
        let url = try fixture(activityCount: 20_000)
        let clock = ContinuousClock()
        let start = clock.now
        async let payload = MerlinProjectImportService.importProjectInBackground(from: url)
        var ticks = 0
        var maxGap = Duration.zero
        var last = clock.now
        while clock.now - start < .milliseconds(300) {
            try await Task.sleep(for: .milliseconds(5))
            maxGap = max(maxGap, clock.now - last)
            last = clock.now
            ticks += 1
        }
        let result = try await payload
        #expect(result.activities.count == 20_000)
        #expect(ticks > 0)
        // Analyse sur le MainActor : un seul tick, écart ≈ durée totale (1,4 s mesuré). Hors MainActor : ≈ 6 ms.
        #expect(maxGap < .milliseconds(500))
        print("[#55] 20000 activités : \(clock.now - start) au total, \(ticks) ticks MainActor, écart max \(maxGap)")
    }

    // MARK: - Fixtures

    private func recordingReporter(_ onStage: @escaping @Sendable (ImportProgressStage) -> Void) -> ImportProgressReporter {
        ImportProgressReporter(setStage: onStage, setTotal: { _ in }, setProcessed: { _ in }, setImported: { _ in })
    }

    private func fixture(activityCount: Int) throws -> URL {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Project xmlns="http://schemas.projectwizards.net/merlin" id="P55">
          <title>Projet volumineux</title>
          <Resource id="R1"><title>Ressource</title></Resource>

        """
        for index in 0..<activityCount {
            xml += "  <Activity id=\"A\(index)\"><title>Activité \(index)</title><Assignment id=\"AS\(index)\"><resource idref=\"R1\"/></Assignment></Activity>\n"
        }
        for index in 1..<activityCount {
            xml += "  <Dependency id=\"D\(index)\"><type value=\"endToStart\"/><previousActivity idref=\"A\(index - 1)\"/><nextActivity idref=\"A\(index)\"/></Dependency>\n"
        }
        xml += "</Project>\n"
        let url = FileManager.default.temporaryDirectory.appending(path: "samourai-merlin-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
