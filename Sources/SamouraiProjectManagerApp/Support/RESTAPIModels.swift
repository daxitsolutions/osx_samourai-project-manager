import Foundation

enum RESTAPIError: LocalizedError {
    case badRequest(String)
    case invalidJSON(String)
    case notFound(String)
    case conflict(String)
    case unsupportedMethod(String)

    var errorDescription: String? {
        switch self {
        case .badRequest(let message),
             .invalidJSON(let message),
             .notFound(let message),
             .conflict(let message),
             .unsupportedMethod(let message):
            message
        }
    }

    var statusCode: Int {
        switch self {
        case .badRequest, .invalidJSON:
            400
        case .notFound:
            404
        case .conflict:
            409
        case .unsupportedMethod:
            405
        }
    }

    var code: String {
        switch self {
        case .badRequest:
            "bad_request"
        case .invalidJSON:
            "invalid_json"
        case .notFound:
            "not_found"
        case .conflict:
            "conflict"
        case .unsupportedMethod:
            "unsupported_method"
        }
    }
}

struct RESTAPIErrorEnvelope: Codable {
    struct ErrorBody: Codable {
        let code: String
        let message: String
    }

    let error: ErrorBody

    init(code: String, message: String) {
        error = ErrorBody(code: code, message: message)
    }
}

struct RESTAPIMetadata: Codable {
    let name: String
    let inputFormat: String
    let outputFormat: String
    let endpoints: [String]
}

struct RESTAPIStatusPayload: Codable {
    let isRunning: Bool
    let port: Int?
    let baseURL: String?
    let inputFormat: String
    let outputFormat: String
}

struct APIRiskRecord: Identifiable, Codable, Hashable {
    var id: UUID { risk.id }
    var projectID: UUID?
    var risk: Risk
}

struct APIDeliverableRecord: Identifiable, Codable, Hashable {
    var id: UUID { deliverable.id }
    var projectID: UUID
    var deliverable: Deliverable
}

struct APIScopeItem: Identifiable, Codable, Hashable {
    var id: String { "\(projectID.uuidString):\(index)" }
    var projectID: UUID
    var index: Int
    var value: String
}
