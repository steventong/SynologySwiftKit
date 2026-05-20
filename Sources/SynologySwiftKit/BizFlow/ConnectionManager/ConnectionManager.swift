import Foundation

final class ConnectionManager: ConnectionManaging {
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let sessionValidator: any ConnectionSessionValidating
    private let apiInfoApi: any ApiInfoProviding
    private let authApi: any AuthenticationProviding
    private let eventPublisher: any ConnectionManagerEventPublishing
    private let optimizationScheduler: any QuickConnectOptimizationScheduling
    private let keyChainStorage: any SensitiveStorage

    init(
        apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating,
        quickConnectApi: QuickConnectClient,
        pingpong: PingPongProviding,
        audioStationApi: AudioStationClient,
        apiInfoApi: any ApiInfoProviding,
        authApi: any AuthenticationProviding,
        eventPublisher: any ConnectionManagerEventPublishing = NotificationCenterConnectionManagerEventPublisher(),
        optimizationScheduler: any QuickConnectOptimizationScheduling = QuickConnectOptimizationCoordinator(),
        keyChainStorage: any SensitiveStorage = StorageService()
    ) {
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.sessionValidator = AudioStationSessionValidator(audioStationApi: audioStationApi)
        self.apiInfoApi = apiInfoApi
        self.authApi = authApi
        self.eventPublisher = eventPublisher
        self.optimizationScheduler = optimizationScheduler
        self.keyChainStorage = keyChainStorage
    }

    func recoverConnection() async -> ConnectionRecoveryDecision {
        guard let credentials = keyChainStorage.getCredentials() else {
            Logger.info("ConnectionManager#recoverConnection, missing credentials")
            return .disconnected
        }

        let serverType = resolveServerType(server: credentials.server)
        let currentConnection = restoreCurrentConnectionFromPersistence()

        if await pingCurrentConnection(currentConnection) {
            return await handleReachableConnection(
                currentConnection,
                serverType: serverType
            )
        }

        return await handleUnreachableConnection(serverType: serverType)
    }

    func refreshQuickConnectEndpoint() async -> SynologyConnection? {
        await optimizationScheduler.run { [weak self] in
            guard let self else {
                return nil
            }
            return await self.performQuickConnectEndpointRefresh()
        }
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

        try await refreshSessionAndSaveConnection(connection)
        return connection
    }
}

private extension ConnectionManager {
    func resolveServerType(server: String) -> ServerType {
        QuickConnectUtils.isQuickConnectId(server: server) ? .quickConnectId : .customDomain
    }

    func handleReachableConnection(
        _ currentConnection: SynologyConnection?,
        serverType: ServerType
    ) async -> ConnectionRecoveryDecision {
        switch await sessionValidator.validateCurrentSession() {
        case .valid:
            if let currentConnection {
                eventPublisher.publishOnlineSessionValidated(
                    SynologyOnlineSessionValidatedEvent(
                        connection: currentConnection,
                        serverType: serverType
                    )
                )
            }

            if serverType == .quickConnectId {
                await scheduleBackgroundQuickConnectEndpointRefresh()
            }

            Logger.info("ConnectionManager#recoverConnection, reachable endpoint with valid session")
            return .connected
        case .invalidSession:
            Logger.info("ConnectionManager#recoverConnection, reachable endpoint but session invalid")
            return .requiresRelogin
        case .validationFailed:
            Logger.warn("ConnectionManager#recoverConnection, reachable endpoint but session validation failed")
            return .requiresRelogin
        }
    }

    func handleUnreachableConnection(serverType: ServerType) async -> ConnectionRecoveryDecision {
        switch serverType {
        case .quickConnectId:
            if await refreshQuickConnectEndpoint() != nil {
                Logger.info("ConnectionManager#recoverConnection, refreshed QuickConnect endpoint")
                return .connected
            }

            Logger.info("ConnectionManager#recoverConnection, QuickConnect refresh failed")
            return .requiresRelogin
        case .customDomain:
            Logger.info("ConnectionManager#recoverConnection, cached custom domain endpoint unreachable")
            return .disconnected
        }
    }

    func scheduleBackgroundQuickConnectEndpointRefresh() async {
        await optimizationScheduler.schedule { [weak self] in
            guard let self else {
                return nil
            }
            return await self.performQuickConnectEndpointRefresh()
        }
    }

    func performQuickConnectEndpointRefresh() async -> SynologyConnection? {
        guard let credentials = keyChainStorage.getCredentials(),
              QuickConnectUtils.isQuickConnectId(server: credentials.server)
        else {
            Logger.info("ConnectionManager#refreshQuickConnectEndpoint, skip non-QuickConnect credentials")
            return nil
        }

        do {
            let previousConnection = restoreCurrentConnectionFromPersistence()
            let connection = try await quickConnectApi.getDeviceConnection(
                quickConnectId: credentials.server,
                usesHTTPS: credentials.usesHTTPS
            )

            guard await pingpong.pingpong(url: connection.url) else {
                Logger.warn("ConnectionManager#refreshQuickConnectEndpoint, resolved endpoint unreachable: \(connection.url)")
                return nil
            }

            try await refreshSessionAndSaveConnection(connection)
            eventPublisher.publishQuickConnectEndpointOptimized(
                SynologyQuickConnectEndpointOptimizedEvent(
                    updatedConnection: connection,
                    previousConnection: previousConnection
                )
            )
            Logger.info("ConnectionManager#refreshQuickConnectEndpoint, refreshed endpoint: \(connection.url)")
            return connection
        } catch {
            Logger.error("ConnectionManager#refreshQuickConnectEndpoint failed: \(error)")
            return nil
        }
    }
}

private extension ConnectionManager {
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

    func sortCandidates(_ lhs: SynologyConnectionCandidate, _ rhs: SynologyConnectionCandidate) -> Bool {
        let lhsPriority = ConnectionType.ordered.firstIndex(of: lhs.type) ?? Int.max
        let rhsPriority = ConnectionType.ordered.firstIndex(of: rhs.type) ?? Int.max
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.url < rhs.url
    }

    func refreshSessionAndSaveConnection(_ connection: SynologyConnection) async throws {
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
