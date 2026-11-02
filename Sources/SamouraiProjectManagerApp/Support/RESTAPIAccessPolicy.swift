import Foundation
@preconcurrency import Network

/// Règles d'exposition de l'API REST locale : écoute sur la boucle locale uniquement,
/// refus des pages web étrangères (Origin) et du DNS rebinding (Host), plafonds de taille et de durée.
/// Les clients locaux sans en-tête Origin (curl, scripts) restent autorisés.
enum RESTAPIAccessPolicy {
    static let maxHeaderBytes = 64 * 1024
    // ponytail: plafond unique couvrant PUT /api/database ; à rendre configurable si une base dépasse 32 Mo.
    static let maxRequestBytes = 32 * 1024 * 1024
    static let requestTimeout: Duration = .seconds(15)

    struct Rejection: Equatable {
        let statusCode: Int
        let code: String
        let message: String
    }

    /// Listener lié explicitement à 127.0.0.1 : aucune interface réseau n'est exposée.
    static func makeListener(port: NWEndpoint.Port) throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
        parameters.allowLocalEndpointReuse = true
        return try NWListener(using: parameters)
    }

    static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case .hostPort(let host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let address): return address.isLoopback
        case .ipv6(let address): return address.isLoopback || address.asIPv4?.isLoopback == true
        case .name(let name, _): return isLoopbackHostName(name)
        @unknown default: return false
        }
    }

    /// Contrôle à appliquer dès que les en-têtes sont reçus, avant tout routage.
    static func rejection(headers: [String: String]) -> Rejection? {
        if let length = headers["content-length"] {
            guard let value = Int(length), value >= 0 else {
                return Rejection(statusCode: 400, code: "bad_request", message: "En-tête Content-Length invalide.")
            }
            if value > maxRequestBytes {
                return tooLarge
            }
        }
        if let host = headers["host"], isAllowedHost(host) == false {
            return Rejection(statusCode: 403, code: "forbidden_host", message: "Hôte non autorisé : l'API n'accepte que localhost.")
        }
        if let origin = headers["origin"], isAllowedOrigin(origin) == false {
            return Rejection(statusCode: 403, code: "forbidden_origin", message: "Origine non autorisée.")
        }
        return nil
    }

    static let tooLarge = Rejection(statusCode: 413, code: "payload_too_large", message: "Requête trop volumineuse.")
    static let timedOut = Rejection(statusCode: 408, code: "request_timeout", message: "Requête incomplète dans le délai imparti.")

    /// En-tête Host attendu d'un client local : localhost, 127.0.0.1 ou [::1], port facultatif.
    static func isAllowedHost(_ value: String) -> Bool {
        let host = value.trimmingCharacters(in: .whitespaces)
        if host.hasPrefix("[") {
            guard let end = host.firstIndex(of: "]") else { return false }
            let rest = host[host.index(after: end)...]
            guard rest.isEmpty || isPortSuffix(rest) else { return false }
            return isLoopbackHostName(String(host[host.index(after: host.startIndex)..<end]))
        }
        let parts = host.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 1 || isPortSuffix(Substring(":" + parts[1])) else { return false }
        return isLoopbackHostName(String(parts[0]))
    }

    /// Seules les pages servies depuis la machine locale peuvent appeler l'API depuis un navigateur.
    static func isAllowedOrigin(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host,
              components.path.isEmpty, components.query == nil, components.user == nil
        else {
            return false
        }
        return isLoopbackHostName(host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
    }

    private static func isLoopbackHostName(_ name: String) -> Bool {
        let host = name.lowercased()
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private static func isPortSuffix(_ value: Substring) -> Bool {
        guard value.first == ":", let port = Int(value.dropFirst()) else { return false }
        return (1...65_535).contains(port)
    }
}
