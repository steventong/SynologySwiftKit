import Foundation

final class ConnectionRouteManager: ConnectionRouteManaging {
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let apiInfoApi: any ApiInfoProviding
    private let authApi: any AuthenticationProviding
    private let keyChainStorage: any SensitiveStorage

    init(
        apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating,
        quickConnectApi: QuickConnectClient,
        pingpong: PingPongProviding,
        apiInfoApi: any ApiInfoProviding,
        authApi: any AuthenticationProviding,
        keyChainStorage: any SensitiveStorage = StorageService()
    ) {
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.apiInfoApi = apiInfoApi
        self.authApi = authApi
        self.keyChainStorage = keyChainStorage
    }

    func listCandidates() async throws -> [SynologyConnectionCandidate] {
        guard let credentials = keyChainStorage.getCredentials() else {
            throw SynologyError.network(message: "Missing saved credentials")
        }

        let currentConnection = restoreCurrentConnectionFromPersistence()
        let currentIdentity = currentConnection.map { "\($0.type.rawValue)|\($0.url)" }

        let connections: [SynologyConnection]
        if QuickConnectUtils.isQuickConnectId(server: credentials.server) {
            connections = try await quickConnectApi.listDeviceConnections(
                quickConnectId: credentials.server,
                usesHTTPS: credentials.usesHTTPS
            )
        } else if let currentConnection {
            connections = [currentConnection]
        } else {
            connections = [SynologyConnection(type: .custom_domain, url: credentials.server)]
        }

        return await withTaskGroup(of: SynologyConnectionCandidate.self) { group in
            for connection in connections {
                group.addTask {
                    let isReachable = await self.pingpong.pingpong(url: connection.url)
                    let identity = "\(connection.type.rawValue)|\(connection.url)"
                    return SynologyConnectionCandidate(
                        url: connection.url,
                        type: connection.type,
                        isCurrent: identity == currentIdentity,
                        isReachable: isReachable
                    )
                }
            }

            var items: [SynologyConnectionCandidate] = []
            for await item in group {
                items.append(item)
            }

            return items.sorted(by: sortCandidates)
        }
    }

    func switchConnection(to connection: SynologyConnection) async throws -> SynologyConnection {
        guard await pingpong.pingpong(url: connection.url) else {
            throw SynologyError.network(message: "Selected endpoint is unreachable")
        }

        let previousConnection = restoreCurrentConnectionFromPersistence()
        let previousSession = apiClient.session ?? keyChainStorage.getSessionInfo()

        saveConnection(url: connection.url, type: connection.type)

        do {
            try await apiInfoApi.refresh()

            guard let credentials = keyChainStorage.getCredentials() else {
                throw SynologyError.network(message: "Missing saved credentials")
            }

            let authResult = try await authApi.login(
                username: credentials.username,
                password: credentials.password,
                otpCode: nil
            )

            apiClient.updateSession(sid: authResult.sid, did: authResult.did)
            keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)
            return connection
        } catch {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            throw error
        }
    }
}

private extension ConnectionRouteManager {
    func restoreCurrentConnectionFromPersistence() -> SynologyConnection? {
        if let connection = apiClient.connection {
            return SynologyConnection(type: connection.type, url: connection.url)
        }

        guard let persisted = keyChainStorage.getConnectionInfo(),
              let type = ConnectionType(rawValue: persisted.typeString)
        else {
            return nil
        }

        apiClient.updateConnection(type: type, url: persisted.url)
        return SynologyConnection(type: type, url: persisted.url)
    }

    func sortCandidates(_ lhs: SynologyConnectionCandidate, _ rhs: SynologyConnectionCandidate) -> Bool {
        let lhsPriority = ConnectionType.ordered.firstIndex(of: lhs.type) ?? Int.max
        let rhsPriority = ConnectionType.ordered.firstIndex(of: rhs.type) ?? Int.max
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.url < rhs.url
    }

    func saveConnection(url: String, type: ConnectionType) {
        apiClient.updateConnection(type: type, url: url)
        keyChainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)
    }

    func rollbackConnection(to connection: SynologyConnection?) {
        guard let connection else {
            return
        }
        saveConnection(url: connection.url, type: connection.type)
    }

    func rollbackSession(to session: (sid: String, did: String?)?) {
        guard let session else {
            apiClient.clearSession()
            keyChainStorage.removeSessionInfo()
            return
        }

        apiClient.updateSession(sid: session.sid, did: session.did)
        keyChainStorage.saveSessionInfo(sid: session.sid, did: session.did)
    }
}
