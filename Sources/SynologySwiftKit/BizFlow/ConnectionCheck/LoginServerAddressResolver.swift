import Foundation

struct LoginConnectionAttempt: Equatable, Sendable {
    let server: String
    let usesHTTPS: Bool
}

enum LoginServerAddressResolver {
    static func automaticAttempts(for input: String) throws -> [LoginConnectionAttempt] {
        let server = trimmed(input)
        guard !server.isEmpty else {
            throw SynologyError.network(message: "Server address is empty")
        }

        if let explicit = explicitAttempt(for: server) {
            return [explicit]
        }

        if QuickConnectUtils.isQuickConnectId(server: server) {
            return [
                LoginConnectionAttempt(server: server, usesHTTPS: true),
                LoginConnectionAttempt(server: server, usesHTTPS: false),
            ]
        }

        return [
            try customDomainAttempt(server: server, scheme: "https", defaultPort: 5001),
            try customDomainAttempt(server: server, scheme: "http", defaultPort: 5000),
        ]
    }

    static func fixedAttempt(for input: String, usesHTTPS: Bool) throws -> LoginConnectionAttempt {
        let server = trimmed(input)
        guard !server.isEmpty else {
            throw SynologyError.network(message: "Server address is empty")
        }

        if let explicit = explicitAttempt(for: server) {
            return explicit
        }

        if QuickConnectUtils.isQuickConnectId(server: server) {
            return LoginConnectionAttempt(server: server, usesHTTPS: usesHTTPS)
        }

        return try customDomainAttempt(
            server: server,
            scheme: usesHTTPS ? "https" : "http",
            defaultPort: usesHTTPS ? 5001 : 5000
        )
    }

    private static func explicitAttempt(for server: String) -> LoginConnectionAttempt? {
        guard let components = URLComponents(string: server),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }
        return LoginConnectionAttempt(server: server, usesHTTPS: scheme == "https")
    }

    private static func customDomainAttempt(
        server: String,
        scheme: String,
        defaultPort: Int
    ) throws -> LoginConnectionAttempt {
        guard var components = URLComponents(string: "\(scheme)://\(server)"),
              components.host != nil
        else {
            throw SynologyError.network(message: "Invalid server address")
        }

        if components.port == nil {
            components.port = defaultPort
        }

        guard let url = components.url else {
            throw SynologyError.network(message: "Invalid server address")
        }
        return LoginConnectionAttempt(server: url.absoluteString, usesHTTPS: scheme == "https")
    }

    private static func trimmed(_ server: String) -> String {
        server.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
