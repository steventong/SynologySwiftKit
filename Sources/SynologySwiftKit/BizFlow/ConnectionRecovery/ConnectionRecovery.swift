import Foundation

final class ConnectionRecovery: ConnectionRecoveryProviding {
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let apiInfoApi: (any ApiInfoProviding)?
    private let authApi: (any AuthenticationProviding)?
    private let keyChainStorage: any SensitiveStorage

    init(
        apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating,
        quickConnectApi: QuickConnectClient,
        pingpong: PingPongProviding,
        apiInfoApi: (any ApiInfoProviding)? = nil,
        authApi: (any AuthenticationProviding)? = nil,
        keyChainStorage: any SensitiveStorage = StorageService()
    ) {
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.apiInfoApi = apiInfoApi
        self.authApi = authApi
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
            if canRefreshSessionAndConnection {
                if await optimizeQuickConnectEndpoint() != nil {
                    Logger.info("ConnectionRecovery#recoverConnection, refreshed QuickConnect endpoint")
                    return ConnectionRecoveryDecision(status: .connected, followUp: nil)
                }

                if isReachable {
                    Logger.info("ConnectionRecovery#recoverConnection, QuickConnect refresh failed, keeping reachable cached endpoint")
                    return ConnectionRecoveryDecision(status: .connected, followUp: nil)
                }

                Logger.info("ConnectionRecovery#recoverConnection, QuickConnect refresh failed and cached endpoint unreachable")
                return ConnectionRecoveryDecision(status: .requiresRelogin, followUp: nil)
            }

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

            try await refreshSessionAndSaveConnection(connection)
            Logger.info("ConnectionRecovery#optimizeQuickConnectEndpoint, refreshed endpoint: \(connection.url)")
            return connection
        } catch {
            Logger.error("ConnectionRecovery#optimizeQuickConnectEndpoint failed: \(error)")
            return nil
        }
    }
}

private extension ConnectionRecovery {
    var canRefreshSessionAndConnection: Bool {
        apiInfoApi != nil && authApi != nil
    }

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

    func refreshSessionAndSaveConnection(_ connection: SynologyConnection) async throws {
        guard let apiInfoApi, let authApi else {
            throw SynologyError.network(message: "Missing login dependencies for connection refresh")
        }

        guard let credentials = keyChainStorage.getCredentials() else {
            throw SynologyError.network(message: "Missing saved credentials")
        }

        let previousConnection = restoreCurrentConnectionFromPersistence()
        let previousSession = apiClient.session ?? keyChainStorage.getSessionInfo()
        apiClient.updateConnection(type: connection.type, url: connection.url)

        do {
            try await apiInfoApi.refresh()
            let authResult = try await authApi.login(
                username: credentials.username,
                password: credentials.password,
                otpCode: nil
            )

            apiClient.updateSession(sid: authResult.sid, did: authResult.did)
            keyChainStorage.saveSessionInfo(sid: authResult.sid, did: authResult.did)
            saveConnection(url: connection.url, type: connection.type)
        } catch {
            rollbackConnection(to: previousConnection)
            rollbackSession(to: previousSession)
            throw error
        }
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
