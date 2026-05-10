import Foundation

final class ConnectionRecovery: ConnectionRecoveryProviding {
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

    func recoverConnection() async -> ConnectionRecoveryDecision {
        guard let credentials = keyChainStorage.getCredentials() else {
            Logger.info("ConnectionRecovery#recoverConnection, missing credentials")
            return ConnectionRecoveryDecision(status: .disconnected, followUp: nil)
        }

        let serverType: ServerType = QuickConnectUtils.isQuickConnectId(server: credentials.server) ? .quickConnectId : .customDomain
        let currentConnection = restoreCurrentConnectionFromPersistence()
        let isReachable = await pingCurrentConnection(currentConnection)

        switch serverType {
        case .quickConnectId:
            if isReachable {
                Logger.info("ConnectionRecovery#recoverConnection, reusing cached QuickConnect endpoint")
                return ConnectionRecoveryDecision(status: .connected, followUp: .optimizeQuickConnectEndpoint)
            }

            Logger.info("ConnectionRecovery#recoverConnection, cached QuickConnect endpoint unreachable")
            return ConnectionRecoveryDecision(status: .requiresRelogin, followUp: nil)
        case .customDomain:
            if isReachable {
                Logger.info("ConnectionRecovery#recoverConnection, reusing cached custom domain endpoint")
                return ConnectionRecoveryDecision(status: .connected, followUp: nil)
            }

            Logger.info("ConnectionRecovery#recoverConnection, cached custom domain endpoint unreachable")
            return ConnectionRecoveryDecision(status: .disconnected, followUp: nil)
        }
    }

    func optimizeQuickConnectEndpoint() async -> SynologyConnection? {
        guard let credentials = keyChainStorage.getCredentials(),
              QuickConnectUtils.isQuickConnectId(server: credentials.server)
        else {
            Logger.info("ConnectionRecovery#optimizeQuickConnectEndpoint, skip non-QuickConnect credentials")
            return nil
        }

        do {
            let connection = try await quickConnectApi.getDeviceConnection(
                quickConnectId: credentials.server,
                usesHTTPS: credentials.usesHTTPS
            )

            guard await pingpong.pingpong(url: connection.url) else {
                Logger.warn("ConnectionRecovery#optimizeQuickConnectEndpoint, resolved endpoint unreachable: \(connection.url)")
                return nil
            }

            saveConnection(url: connection.url, type: connection.type)
            Logger.info("ConnectionRecovery#optimizeQuickConnectEndpoint, refreshed endpoint: \(connection.url)")
            return connection
        } catch {
            Logger.error("ConnectionRecovery#optimizeQuickConnectEndpoint failed: \(error)")
            return nil
        }
    }
}

private extension ConnectionRecovery {
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

    func pingCurrentConnection(_ connection: SynologyConnection?) async -> Bool {
        guard let connection else {
            return false
        }
        return await pingpong.pingpong(url: connection.url)
    }

    func saveConnection(url: String, type: ConnectionType) {
        apiClient.updateConnection(type: type, url: url)
        keyChainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)
    }
}
