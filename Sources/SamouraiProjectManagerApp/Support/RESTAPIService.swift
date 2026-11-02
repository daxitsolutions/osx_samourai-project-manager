import Darwin
import Foundation
@preconcurrency import Network
import Observation

@MainActor
@Observable
final class RESTAPIService {
    enum State: String {
        case stopped
        case starting
        case running
        case failed
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "samourai.rest-api.listener", qos: .userInitiated)

    private(set) var state: State = .stopped
    private(set) var activePort: Int?
    private(set) var statusMessage = "Serveur arrêté."
    private(set) var lastErrorMessage: String?
    /// Délai maximal de réception d'une requête complète ; réduit par les tests.
    var requestTimeout = RESTAPIAccessPolicy.requestTimeout

    var isRunning: Bool { state == .running }

    var baseURL: String? {
        guard let activePort else { return nil }
        return "http://127.0.0.1:\(activePort)/api"
    }

    func start(port: Int, store: SamouraiStore) throws {
        guard AppState.isValidRESTAPIPort(port) else {
            throw RESTAPIError.badRequest("Le port doit être compris entre 1024 et 65535.")
        }

        stop()
        state = .starting
        activePort = port
        statusMessage = "Démarrage du serveur API REST..."
        lastErrorMessage = nil

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw RESTAPIError.badRequest("Port invalide.")
        }

        let listener = try RESTAPIAccessPolicy.makeListener(port: nwPort)
        let queue = queue
        let timeout = requestTimeout
        listener.newConnectionHandler = { [weak store, weak self] connection in
            // Défense en profondeur : le listener est lié à 127.0.0.1, toute autre provenance est coupée.
            guard let store, let self, RESTAPIAccessPolicy.isLoopback(connection.endpoint) else {
                connection.cancel()
                return
            }
            RESTAPIConnection(connection: connection, store: store, service: self, queue: queue, timeout: timeout).start()
        }
        listener.stateUpdateHandler = { [weak self] listenerState in
            Task { @MainActor in
                self?.handleListenerState(listenerState, port: port)
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        state = .stopped
        activePort = nil
        statusMessage = "Serveur arrêté."
    }

    func restart(port: Int, store: SamouraiStore) throws {
        stop()
        try start(port: port, store: store)
    }

    func reportConfigurationError(_ message: String) {
        if state != .running {
            state = .failed
            activePort = nil
            statusMessage = "Serveur arrêté."
        }
        lastErrorMessage = message
    }

    static func isPortAvailable(_ port: Int) -> Bool {
        guard AppState.isValidRESTAPIPort(port) else { return false }

        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var reuse = 1
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    private func handleListenerState(_ listenerState: NWListener.State, port: Int) {
        switch listenerState {
        case .ready:
            state = .running
            activePort = port
            statusMessage = "Serveur actif sur http://127.0.0.1:\(port) (accès local uniquement)"
            lastErrorMessage = nil
        case .failed(let error):
            state = .failed
            activePort = nil
            statusMessage = "Serveur arrêté."
            lastErrorMessage = "API REST indisponible : \(error.localizedDescription)"
            listener?.cancel()
            listener = nil
        case .cancelled:
            if state != .stopped {
                state = .stopped
                activePort = nil
                statusMessage = "Serveur arrêté."
            }
        default:
            break
        }
    }
}

private final class RESTAPIConnection: @unchecked Sendable {
    private let connection: NWConnection
    private weak var store: SamouraiStore?
    private weak var service: RESTAPIService?
    private let queue: DispatchQueue
    private let timeout: Duration
    private var buffer = Data()
    /// `receiving` → `processing` → `finished`, modifié uniquement sur `queue`.
    private var phase = Phase.receiving

    private enum Phase { case receiving, processing, finished }

    init(connection: NWConnection, store: SamouraiStore, service: RESTAPIService, queue: DispatchQueue, timeout: Duration) {
        self.connection = connection
        self.store = store
        self.service = service
        self.queue = queue
        self.timeout = timeout
    }

    func start() {
        connection.start(queue: queue)
        let (seconds, attoseconds) = timeout.components
        let delay = Double(seconds) + Double(attoseconds) / 1e18
        // Une connexion lente ou muette n'occupe pas le serveur indéfiniment.
        queue.asyncAfter(deadline: .now() + delay) { [self] in
            guard phase == .receiving else { return }
            reject(RESTAPIAccessPolicy.timedOut)
        }
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [self] data, _, isComplete, error in
            guard phase == .receiving else { return }
            if let data, data.isEmpty == false {
                buffer.append(data)
            }

            if let error {
                reject(.init(statusCode: 400, code: "connection_error", message: error.localizedDescription))
                return
            }

            guard buffer.count <= RESTAPIAccessPolicy.maxRequestBytes else {
                reject(RESTAPIAccessPolicy.tooLarge)
                return
            }

            guard let request = HTTPRequest(data: buffer) else {
                if buffer.count > RESTAPIAccessPolicy.maxHeaderBytes {
                    reject(.init(statusCode: 431, code: "headers_too_large", message: "En-têtes HTTP trop volumineux."))
                } else if isComplete {
                    reject(.init(statusCode: 400, code: "bad_request", message: "Requête HTTP invalide."))
                } else {
                    receive()
                }
                return
            }

            if let rejection = RESTAPIAccessPolicy.rejection(headers: request.headers) {
                reject(rejection)
                return
            }

            if request.body.count >= request.contentLength || isComplete {
                phase = .processing
                Task { @MainActor in
                    guard let store = self.store else {
                        self.finish(RESTAPIResponse.error(statusCode: 503, code: "store_unavailable", message: "Store indisponible."))
                        return
                    }
                    let response = RESTAPIRequestRouter.response(
                        for: request,
                        store: store,
                        service: self.service
                    )
                    self.finish(response)
                }
            } else {
                receive()
            }
        }
    }

    /// Appelé sur `queue`.
    private func reject(_ rejection: RESTAPIAccessPolicy.Rejection) {
        phase = .processing
        finish(.error(statusCode: rejection.statusCode, code: rejection.code, message: rejection.message))
    }

    private func finish(_ response: RESTAPIResponse) {
        queue.async { [self] in
            guard phase != .finished else { return }
            phase = .finished
            connection.send(content: response.rawData, completion: .contentProcessed { [connection] _ in
                connection.cancel()
            })
        }
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var contentLength: Int {
        Int(headers["content-length"] ?? "") ?? 0
    }

    init?(data: Data) {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator),
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8)
        else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestLineParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestLineParts.count >= 2 else { return nil }

        var parsedHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separatorIndex = line.firstIndex(of: ":") else { continue }
            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            parsedHeaders[key] = value
        }

        method = requestLineParts[0].uppercased()
        path = requestLineParts[1]
        headers = parsedHeaders
        body = data[headerRange.upperBound...]
    }

    var pathComponents: [String] {
        let cleanPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        return cleanPath
            .split(separator: "/")
            .map(String.init)
            .map { $0.removingPercentEncoding ?? $0 }
    }

    var hasJSONContentType: Bool {
        headers["content-type"]?.lowercased().contains("application/json") == true
    }
}

private struct RESTAPIResponse {
    let statusCode: Int
    let body: Data
    /// Origine locale déjà validée, renvoyée telle quelle ; jamais de joker `*`.
    var allowedOrigin: String?

    var rawData: Data {
        var payload = Data()
        let statusLine = "HTTP/1.1 \(statusCode) \(Self.reasonPhrase(for: statusCode))\r\n"
        var headerLines = [
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(body.count)",
            "Connection: close",
            "Vary: Origin"
        ]
        if let allowedOrigin {
            headerLines += [
                "Access-Control-Allow-Origin: \(allowedOrigin)",
                "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS",
                "Access-Control-Allow-Headers: Content-Type"
            ]
        }
        let headers = headerLines.joined(separator: "\r\n")
        payload.append(Data(statusLine.utf8))
        payload.append(Data(headers.utf8))
        payload.append(Data("\r\n\r\n".utf8))
        payload.append(body)
        return payload
    }

    static func json<T: Encodable>(_ value: T, statusCode: Int = 200) -> RESTAPIResponse {
        do {
            return RESTAPIResponse(statusCode: statusCode, body: try SamouraiPersistence.makeEncoder().encode(value))
        } catch {
            return self.error(statusCode: 500, code: "encoding_error", message: error.localizedDescription)
        }
    }

    static func empty(statusCode: Int = 204) -> RESTAPIResponse {
        RESTAPIResponse(statusCode: statusCode, body: Data("{}".utf8))
    }

    static func error(statusCode: Int, code: String, message: String) -> RESTAPIResponse {
        json(RESTAPIErrorEnvelope(code: code, message: message), statusCode: statusCode)
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 408: "Request Timeout"
        case 409: "Conflict"
        case 413: "Content Too Large"
        case 431: "Request Header Fields Too Large"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "OK"
        }
    }
}

@MainActor
private enum RESTAPIRequestRouter {
    private static let decoder = SamouraiPersistence.makeDecoder()

    /// La requête a déjà passé `RESTAPIAccessPolicy` : son éventuelle origine est locale.
    static func response(for request: HTTPRequest, store: SamouraiStore, service: RESTAPIService?) -> RESTAPIResponse {
        var response = routedResponse(for: request, store: store, service: service)
        response.allowedOrigin = request.headers["origin"]
        return response
    }

    private static func routedResponse(for request: HTTPRequest, store: SamouraiStore, service: RESTAPIService?) -> RESTAPIResponse {
        if request.method == "OPTIONS" {
            return .empty(statusCode: 204)
        }

        do {
            return try route(request, store: store, service: service)
        } catch let error as RESTAPIError {
            return RESTAPIResponse.error(
                statusCode: error.statusCode,
                code: error.code,
                message: error.localizedDescription
            )
        } catch {
            return RESTAPIResponse.error(statusCode: 500, code: "internal_error", message: error.localizedDescription)
        }
    }

    private static func route(_ request: HTTPRequest, store: SamouraiStore, service: RESTAPIService?) throws -> RESTAPIResponse {
        let components = request.pathComponents
        guard components.first == "api" else {
            throw RESTAPIError.notFound("Endpoint introuvable.")
        }

        if components.count == 1 {
            return .json(metadata)
        }

        if components.count == 2, components[1] == "status" {
            return .json(
                RESTAPIStatusPayload(
                    isRunning: service?.isRunning == true,
                    port: service?.activePort,
                    baseURL: service?.baseURL,
                    inputFormat: "JSON (application/json)",
                    outputFormat: "JSON (application/json)"
                )
            )
        }

        if components.count == 2, components[1] == "database" {
            switch request.method {
            case "GET":
                return .json(store.apiDatabaseSnapshot())
            case "PUT":
                let database: SamouraiDatabase = try decodeBody(from: request)
                try store.apiReplaceDatabase(database)
                return .json(store.apiDatabaseSnapshot())
            default:
                throw RESTAPIError.unsupportedMethod("Méthode non supportée pour /api/database.")
            }
        }

        if components.count >= 2, components[1] == "scope-in" || components[1] == "scope-out" {
            return try routeScope(request, components: components, store: store, inScope: components[1] == "scope-in")
        }

        guard components.count >= 2 else {
            throw RESTAPIError.notFound("Endpoint introuvable.")
        }

        let collection = components[1]
        let id = components.count >= 3 ? UUID(uuidString: components[2]) : nil
        if components.count >= 3, id == nil {
            throw RESTAPIError.badRequest("Identifiant UUID invalide.")
        }

        switch collection {
        case "projects":
            return try routeCollection(
                request,
                id: id,
                list: store.projects,
                get: store.project(with:),
                upsert: store.apiUpsertProject,
                delete: store.apiDeleteProject
            )
        case "resources", "resource-directory":
            return try routeCollection(
                request,
                id: id,
                list: store.resources,
                get: store.resource(with:),
                upsert: store.apiUpsertResource,
                delete: store.apiDeleteResource
            )
        case "events":
            return try routeCollection(
                request,
                id: id,
                list: store.events,
                get: store.event(with:),
                upsert: store.apiUpsertEvent,
                delete: store.apiDeleteEvent
            )
        case "actions", "pmactions":
            return try routeCollection(
                request,
                id: id,
                list: store.actions,
                get: store.action(with:),
                upsert: store.apiUpsertAction,
                delete: store.apiDeleteAction
            )
        case "meetings":
            return try routeCollection(
                request,
                id: id,
                list: store.meetings,
                get: store.meeting(with:),
                upsert: store.apiUpsertMeeting,
                delete: store.apiDeleteMeeting
            )
        case "decisions":
            return try routeCollection(
                request,
                id: id,
                list: store.decisions,
                get: store.decision(with:),
                upsert: store.apiUpsertDecision,
                delete: store.apiDeleteDecision
            )
        case "activities":
            return try routeCollection(
                request,
                id: id,
                list: store.activities,
                get: store.activity(with:),
                upsert: store.apiUpsertActivity,
                delete: store.apiDeleteActivity
            )
        case "risks":
            return try routeWrappedCollection(
                request,
                id: id,
                list: store.apiRiskRecords(),
                get: { targetID in store.apiRiskRecords().first { $0.risk.id == targetID } },
                upsert: store.apiUpsertRisk,
                delete: store.apiDeleteRisk
            )
        case "deliverables", "delivrables":
            return try routeWrappedCollection(
                request,
                id: id,
                list: store.apiDeliverableRecords(),
                get: { targetID in store.apiDeliverableRecords().first { $0.deliverable.id == targetID } },
                upsert: store.apiUpsertDeliverable,
                delete: store.apiDeleteDeliverable
            )
        default:
            throw RESTAPIError.notFound("Collection API inconnue.")
        }
    }

    private static func routeCollection<T: Identifiable & Codable>(
        _ request: HTTPRequest,
        id: UUID?,
        list: [T],
        get: (UUID) -> T?,
        upsert: (T, UUID?) throws -> T,
        delete: (UUID) throws -> Void
    ) throws -> RESTAPIResponse where T.ID == UUID {
        switch (request.method, id) {
        case ("GET", nil):
            return .json(list)
        case ("GET", let targetID?):
            guard let item = get(targetID) else { throw RESTAPIError.notFound("Objet introuvable.") }
            return .json(item)
        case ("POST", nil):
            let item: T = try decodeBody(from: request)
            return .json(try upsert(item, nil), statusCode: 201)
        case ("PUT", let targetID?):
            let item: T = try decodeBody(from: request)
            return .json(try upsert(item, targetID))
        case ("DELETE", let targetID?):
            try delete(targetID)
            return .empty(statusCode: 204)
        default:
            throw RESTAPIError.unsupportedMethod("Méthode non supportée pour cette collection.")
        }
    }

    private static func routeWrappedCollection<T: Identifiable & Codable>(
        _ request: HTTPRequest,
        id: UUID?,
        list: [T],
        get: (UUID) -> T?,
        upsert: (T, UUID?) throws -> T,
        delete: (UUID) throws -> Void
    ) throws -> RESTAPIResponse where T.ID == UUID {
        try routeCollection(request, id: id, list: list, get: get, upsert: upsert, delete: delete)
    }

    private static func routeScope(
        _ request: HTTPRequest,
        components: [String],
        store: SamouraiStore,
        inScope: Bool
    ) throws -> RESTAPIResponse {
        switch request.method {
        case "GET" where components.count == 2:
            return .json(store.apiScopeItems(inScope: inScope))
        case "POST" where components.count == 2:
            let item: APIScopeItem = try decodeBody(from: request)
            return .json(try store.apiAppendScopeItem(item, inScope: inScope), statusCode: 201)
        case "PUT" where components.count == 4,
             "DELETE" where components.count == 4:
            guard let projectID = UUID(uuidString: components[2]), let index = Int(components[3]) else {
                throw RESTAPIError.badRequest("Chemin de périmètre invalide. Utilise /api/scope-in/{projectID}/{index}.")
            }
            if request.method == "DELETE" {
                try store.apiDeleteScopeItem(projectID: projectID, index: index, inScope: inScope)
                return .empty(statusCode: 204)
            }
            let item: APIScopeItem = try decodeBody(from: request)
            return .json(try store.apiReplaceScopeItem(projectID: projectID, index: index, value: item.value, inScope: inScope))
        default:
            throw RESTAPIError.unsupportedMethod("Méthode non supportée pour le périmètre.")
        }
    }

    private static func decodeBody<T: Decodable>(from request: HTTPRequest) throws -> T {
        guard request.hasJSONContentType else {
            throw RESTAPIError.invalidJSON("Le header Content-Type doit être application/json.")
        }
        do {
            return try decoder.decode(T.self, from: request.body)
        } catch {
            throw RESTAPIError.invalidJSON("JSON invalide : \(error.localizedDescription)")
        }
    }

    private static var metadata: RESTAPIMetadata {
        RESTAPIMetadata(
            name: "Samourai Project Manager REST API",
            inputFormat: "JSON (application/json)",
            outputFormat: "JSON (application/json)",
            endpoints: [
                "/api/status",
                "/api/database",
                "/api/projects",
                "/api/resources",
                "/api/resource-directory",
                "/api/risks",
                "/api/actions",
                "/api/decisions",
                "/api/events",
                "/api/meetings",
                "/api/deliverables",
                "/api/activities",
                "/api/scope-in",
                "/api/scope-out"
            ]
        )
    }
}
