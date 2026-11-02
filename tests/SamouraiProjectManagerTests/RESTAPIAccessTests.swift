import Darwin
import Foundation
import Testing
@testable import SamouraiProjectManagerApp

/// Issue #39 : l'API REST n'écoute que sur la boucle locale, refuse les origines et hôtes étrangers,
/// borne la taille et la durée des requêtes, et reste utilisable par un client local.
@MainActor
@Suite(.serialized)
struct RESTAPIAccessTests {
    @Test
    func policyAcceptsOnlyLoopbackHostsAndOrigins() {
        for host in ["localhost", "localhost:8080", "127.0.0.1", "127.0.0.1:9000", "[::1]", "[::1]:8080", "LOCALHOST"] {
            #expect(RESTAPIAccessPolicy.isAllowedHost(host), "\(host)")
        }
        for host in ["evil.example", "evil.example:8080", "192.168.1.10", "localhost.evil.example", "localhost:", "[::2]", "127.0.0.1:99999"] {
            #expect(!RESTAPIAccessPolicy.isAllowedHost(host), "\(host)")
        }
        for origin in ["http://localhost:3000", "http://127.0.0.1", "https://[::1]:8443"] {
            #expect(RESTAPIAccessPolicy.isAllowedOrigin(origin), "\(origin)")
        }
        for origin in ["https://evil.example", "null", "file://", "http://localhost.evil.example", "http://192.168.1.10"] {
            #expect(!RESTAPIAccessPolicy.isAllowedOrigin(origin), "\(origin)")
        }
        #expect(RESTAPIAccessPolicy.rejection(headers: ["content-length": "-1"])?.statusCode == 400)
        #expect(RESTAPIAccessPolicy.rejection(headers: ["content-length": "\(RESTAPIAccessPolicy.maxRequestBytes + 1)"])?.statusCode == 413)
        #expect(RESTAPIAccessPolicy.rejection(headers: ["host": "127.0.0.1:8080", "content-length": "12"]) == nil)
    }

    @Test
    func listenerIsNotReachableFromANetworkInterface() async throws {
        try await withRunningService { _, _, port in
            let local = try await exchange(port: port, "GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
            #expect(local.hasPrefix("HTTP/1.1 200"))
            // Avant correction, le listener acceptait toutes les interfaces : la connexion par l'IP réseau aboutissait.
            guard let address = Self.nonLoopbackIPv4Address() else { return }
            let remote = try await exchange(port: port, host: address, "GET /api/status HTTP/1.1\r\n\r\n")
            #expect(remote.isEmpty, "Connexion acceptée via \(address)")
        }
    }

    @Test
    func localClientsKeepReadAndWriteAccessWithoutWildcardCORS() async throws {
        try await withRunningService { store, _, port in
            let status = try await exchange(port: port, "GET /api/status HTTP/1.1\r\nHost: localhost:\(port)\r\n\r\n")
            #expect(status.hasPrefix("HTTP/1.1 200"))
            #expect(!status.contains("Access-Control-Allow-Origin"))
            #expect(status.contains("127.0.0.1:\(port)"))

            let localPage = try await exchange(port: port, "GET /api/projects HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: http://localhost:3000\r\n\r\n")
            #expect(localPage.hasPrefix("HTTP/1.1 200"))
            #expect(localPage.contains("Access-Control-Allow-Origin: http://localhost:3000\r\n"))

            let body = try SamouraiPersistence.makeEncoder().encode(store.apiDatabaseSnapshot())
            let write = try await exchange(port: port, Data((
                "PUT /api/database HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\n"
                + "Content-Length: \(body.count)\r\n\r\n").utf8) + body)
            #expect(write.hasPrefix("HTTP/1.1 200"))
            #expect(store.projects.count == 1)
        }
    }

    @Test
    func foreignOriginsAndHostsCannotReadOrWrite() async throws {
        try await withRunningService { store, projectID, port in
            let requests = [
                "DELETE /api/projects/\(projectID) HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: https://evil.example\r\n\r\n",
                "OPTIONS /api/database HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: https://evil.example\r\n"
                    + "Access-Control-Request-Method: PUT\r\n\r\n",
                "GET /api/database HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: null\r\n\r\n",
                // DNS rebinding : la page étrangère se présente avec son propre nom d'hôte.
                "DELETE /api/projects/\(projectID) HTTP/1.1\r\nHost: evil.example:\(port)\r\n\r\n"
            ]
            for request in requests {
                let response = try await exchange(port: port, request)
                #expect(response.hasPrefix("HTTP/1.1 403"), "\(request)")
                #expect(!response.contains("Access-Control-Allow-Origin"))
                #expect(!response.contains("\"projects\""))
            }
            #expect(store.project(with: projectID) != nil)
        }
    }

    @Test
    func requestSizeAndDurationAreBounded() async throws {
        try await withRunningService(timeout: .milliseconds(300)) { store, projectID, port in
            let oversized = try await exchange(port: port,
                "PUT /api/database HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\n"
                + "Content-Length: \(RESTAPIAccessPolicy.maxRequestBytes + 1)\r\n\r\n")
            #expect(oversized.hasPrefix("HTTP/1.1 413"))

            // Taille exacte : le rejet survient sur le dernier octet, sans données non lues provoquant un RST.
            let prefix = "GET /api/status HTTP/1.1\r\nX-Pad: "
            let endlessHeaders = prefix + String(repeating: "a", count: RESTAPIAccessPolicy.maxHeaderBytes + 1 - prefix.utf8.count)
            let headers = try await exchange(port: port, endlessHeaders)
            #expect(headers.hasPrefix("HTTP/1.1 431"))

            let started = ContinuousClock.now
            let slow = try await exchange(port: port, "DELETE /api/projects/\(projectID) HTTP/1.1\r\nHost: 127.0.0.1\r\n")
            #expect(slow.hasPrefix("HTTP/1.1 408"))
            #expect(ContinuousClock.now - started < .seconds(4))

            let truncatedBody = try await exchange(port: port,
                "PUT /api/database HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: 1000\r\n\r\n{")
            #expect(truncatedBody.hasPrefix("HTTP/1.1 408"))
            #expect(store.project(with: projectID) != nil)
        }
    }

    // MARK: - Banc

    private func withRunningService(
        timeout: Duration = RESTAPIAccessPolicy.requestTimeout,
        test: (SamouraiStore, UUID, Int) async throws -> Void
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "samourai-rest-api-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SamouraiStore(persistence: SamouraiPersistence(fileURL: root.appending(path: "projects.json"), migrationSourceURL: nil))
        await store.loadIfNeeded()
        let projectID = try #require(store.addProject(
            name: "Projet API", summary: "", sponsor: "", manager: "", phase: .cadrage,
            health: .green, deliveryMode: .waterfall, startDate: .now, targetDate: .now
        ))

        let service = RESTAPIService()
        service.requestTimeout = timeout
        let port = try #require(Self.freeLoopbackPort())
        try service.start(port: port, store: store)
        defer { service.stop() }
        for _ in 0..<100 where !service.isRunning {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(service.isRunning)
        try await test(store, projectID, port)
        store.flushSynchronously()
    }

    private func exchange(port: Int, host: String = "127.0.0.1", _ request: String) async throws -> String {
        try await exchange(port: port, host: host, Data(request.utf8))
    }

    /// Socket brute hors du MainActor : le routeur s'exécute sur le MainActor et doit rester libre.
    /// Renvoie une chaîne vide si la connexion est refusée.
    private func exchange(port: Int, host: String = "127.0.0.1", _ request: Data) async throws -> String {
        try await Task.detached {
            let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            guard descriptor >= 0 else { throw POSIXError(.EBADF) }
            defer { close(descriptor) }
            var timeout = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(port).bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr(host))
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard connected == 0 else { return "" }
            _ = request.withUnsafeBytes { send(descriptor, $0.baseAddress, $0.count, 0) }
            var response = Data()
            var chunk = [UInt8](repeating: 0, count: 65_536)
            while true {
                let count = recv(descriptor, &chunk, chunk.count, 0)
                guard count > 0 else { break }
                response.append(contentsOf: chunk[..<count])
            }
            return String(decoding: response, as: UTF8.self)
        }.value
    }

    private static func freeLoopbackPort() -> Int? {
        for port in Int.random(in: 20_000...40_000)...40_100 where RESTAPIService.isPortAvailable(port) {
            return port
        }
        return nil
    }

    private static func nonLoopbackIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard let address = pointer.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return nil
    }
}
