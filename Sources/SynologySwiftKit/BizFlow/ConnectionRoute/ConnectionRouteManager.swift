import Foundation

final class ConnectionRouteManager: ConnectionRouteManaging {
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let keyChainStorage: any SensitiveStorage

    init(
        apiClient: ConnectionStateProviding & ConnectionStateUpdating,
        quickConnectApi: QuickConnectClient,
        pingpong: PingPongProviding,
        keyChainStorage: any SensitiveStorage = StorageService()
    ) {
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
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

        apiClient.updateConnection(type: connection.type, url: connection.url)
        keyChainStorage.saveConnectionInfo(url: connection.url, typeString: connection.type.rawValue)
        return connection
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
}
