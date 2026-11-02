import Foundation
import SQLite3
import Synchronization
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #55 : lecture et analyse Merlin hors du MainActor, annulables pendant l'analyse.
@MainActor
struct MerlinBackgroundImportTests {
    @Test func xmlParsingRunsOffMainThread() async throws {
        let url = try fixture(activityCount: 50)
        defer { try? FileManager.default.removeItem(at: url) }
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
        defer { try? FileManager.default.removeItem(at: url) }
        let reporter = recordingReporter { current in
            if current == stage { withUnsafeCurrentTask { $0?.cancel() } }
        }

        let task = Task { try await MerlinProjectImportService.importProjectInBackground(from: url, reporter: reporter) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func backgroundResultMatchesSynchronousParsing() async throws {
        let url = try fixture(activityCount: 5_000)
        defer { try? FileManager.default.removeItem(at: url) }
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
        defer { try? FileManager.default.removeItem(at: url) }
        let clock = ContinuousClock()
        let start = clock.now
        let responsive = ResponsivenessProbe()
        let reporter = responsive.reporter
        async let payload = MerlinProjectImportService.importProjectInBackground(from: url, reporter: reporter)
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
        // Other parallel tests can occupy MainActor: assert the synchronized probe,
        // and keep the observed scheduling gap as a measurement rather than a machine-speed gate.
        #expect(responsive.responded.withLock { $0 })
        print("[#55] 20000 activités : \(clock.now - start) au total, \(ticks) ticks MainActor, écart max \(maxGap)")
    }

    @Test func largeNativeDatabaseStaysResponsiveAndMatchesSync() async throws {
        let package = FileManager.default.temporaryDirectory.appending(path: "samourai-native-\(UUID()).mproject", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: package) }
        var db: OpaquePointer?
        #expect(sqlite3_open(package.appending(path: "state.sql").path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let schema = """
        CREATE TABLE ZPROJECT (Z_PK, ZTITLE, ZUNIQUEID, ZROOTACTIVITY, ZHOURSPERDAY, ZHOURSPERWEEK, ZDAYSPERMONTH, ZCURRENCYSYMBOL);
        INSERT INTO ZPROJECT VALUES (1, 'Synthetic native project', 'P55', NULL, 8, 40, 20, 'EUR');
        CREATE TABLE ZSCHEDULEITEM (Z_PK, Z_ENT, ZTITLE, ZUNIQUEID, ZPROJECT, ZPARENTACTIVITY_, Z45_PARENTACTIVITY_, ZACTIVITY_, Z45_ACTIVITY_, ZRESOURCE, ZORDERINPARENTACTIVITY, ZORDERINACTIVITY, ZISMILESTONE, ZPRIORITY, ZGIVENSTARTDATEMIN_, ZGIVENSTARTDATEMAX_, ZGIVENENDDATEMIN_, ZGIVENENDDATEMAX_, ZGIVENWORK_, ZRESOURCEUNITS_, ZOBJECTDESCRIPTION);
        WITH RECURSIVE seq(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM seq WHERE n<20000)
        INSERT INTO ZSCHEDULEITEM (Z_PK, Z_ENT, ZTITLE, ZUNIQUEID, ZPROJECT, ZORDERINPARENTACTIVITY) SELECT n, 45, 'Activity '||n, 'A'||n, 1, n FROM seq;
        CREATE TABLE ZRESOURCE (Z_PK, ZTITLE_, ZUNIQUEID, ZTYPE, ZISUSER, ZINITIALS_, ZEMAIL, ZPHONE, ZORDERINPROJECT, ZRESOURCECALENDAR, ZAVAILABLEUNITS_, ZPROJECT);
        CREATE TABLE ZDEPENDENCY (Z_PK, ZTYPE, ZNEXTACTIVITY_, ZPREVIOUSACTIVITY_, ZUNIQUEID, ZPROJECT);
        CREATE TABLE ZCALENDAR (Z_PK, ZTITLE, ZUNIQUEID, ZBASECALENDAR, ZRESOURCE, ZPROJECT);
        CREATE TABLE ZCUSTOMATTRIBUTE (Z_PK, ZTITLE_, ZUNIQUEID, ZTARGETENTITYNAME, ZTYPE, ZUNIT, ZPROJECT);
        """
        #expect(sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK)
        let stages = Mutex<[Bool]>([])
        let responsive = ResponsivenessProbe()
        let probe = responsive.reporter
        let reporter = recordingReporter { stage in
            stages.withLock { $0.append(pthread_main_np() != 0) }
            probe.setStage(stage)
        }
        let clock = ContinuousClock()
        let start = clock.now
        async let payload = MerlinProjectImportService.importProjectInBackground(from: package, reporter: reporter)
        var last = clock.now
        var maxGap = Duration.zero
        var ticks = 0
        while clock.now - start < .milliseconds(300) {
            try await Task.sleep(for: .milliseconds(5))
            maxGap = max(maxGap, clock.now - last)
            last = clock.now
            ticks += 1
        }
        let result = try await payload
        let elapsed = clock.now - start
        #expect(result.activities.count == 20_000)
        #expect(stages.withLock { $0 } == [false, false])
        #expect(responsive.responded.withLock { $0 })
        let sync = try await Task.detached { try MerlinProjectImportService.importProject(from: package) }.value
        #expect(result.activities.map(\.id) == sync.activities.map(\.id))
        print("[#55] SQLite 20000 activities: \(elapsed), \(ticks) MainActor ticks, max gap \(maxGap)")
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


/// A MainActor callback must reply while the parsing worker waits. Moving the
/// parser onto MainActor is detected before waiting, so unrelated MainActor
/// work cannot turn a scheduling delay into a false failure.
private final class ResponsivenessProbe: Sendable {
    let responded = Mutex<Bool>(false)
    var reporter: ImportProgressReporter {
        ImportProgressReporter(setStage: { [self] stage in
            guard stage == .parsing else { return }
            // A synchronous callback on MainActor cannot wait for itself. Detect
            // that regression directly, then let a background worker await the
            // reply without imposing a speed limit on unrelated parallel tests.
            guard pthread_main_np() == 0 else { return }
            let signal = DispatchSemaphore(value: 0)
            Task { @MainActor in signal.signal() }
            signal.wait()
            responded.withLock { $0 = true }
        }, setTotal: { _ in }, setProcessed: { _ in }, setImported: { _ in })
    }
}
