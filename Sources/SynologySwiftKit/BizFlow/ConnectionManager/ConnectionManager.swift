import Foundation

final class ConnectionManager: ConnectionManaging {
    private let sessionOperations: SessionOperationCoordinator
    private let apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating
    private let quickConnectApi: QuickConnectClient
    private let pingpong: PingPongProviding
    private let sessionValidator: any ConnectionSessionValidating
    private let apiInfoApi: any ApiInfoProviding
    private let eventPublisher: any ConnectionManagerEventPublishing
    private let optimizationScheduler: any QuickConnectOptimizationScheduling
    private let keyChainStorage: any SensitiveStorage

    init(
        apiClient: ConnectionStateProviding & ConnectionStateUpdating & SessionStateProviding & SessionStateUpdating,
        quickConnectApi: QuickConnectClient,
        pingpong: PingPongProviding,
        dsmInfoApi: DSMInfoClient,
        sessionValidationTimeout: TimeInterval = 3.6,
        apiInfoApi: any ApiInfoProviding,
        eventPublisher: any ConnectionManagerEventPublishing = NotificationCenterConnectionManagerEventPublisher(),
        optimizationScheduler: any QuickConnectOptimizationScheduling = QuickConnectOptimizationCoordinator(),
        keyChainStorage: any SensitiveStorage = StorageService(),
        sessionOperations: SessionOperationCoordinator = SessionOperationCoordinator()
    ) {
        self.sessionOperations = sessionOperations
        self.apiClient = apiClient
        self.quickConnectApi = quickConnectApi
        self.pingpong = pingpong
        self.sessionValidator = DSMSessionValidator(dsmInfoApi: dsmInfoApi, timeout: sessionValidationTimeout)
        self.apiInfoApi = apiInfoApi
        self.eventPublisher = eventPublisher
        self.optimizationScheduler = optimizationScheduler
        self.keyChainStorage = keyChainStorage
    }

    func recoverConnection() async -> ConnectionRecoveryDecision {
        (try? await sessionOperations.perform { await self.performRecovery() }) ?? .disconnected
    }

    private func performRecovery() async -> ConnectionRecoveryDecision {
        guard let credentials = keyChainStorage.getCredentials() else {
            Logger.info("ConnectionManager#recoverConnection, missing credentials")
            return .disconnected
        }

        apiInfoApi.selectServer(credentials.server)
        let serverType = resolveServerType(server: credentials.server)
        let currentConnection = restoreCurrentConnectionFromPersistence()
        // 恢复网络必须沿用已有会话；没有 SID 不代表服务器已判定会话过期。
        guard let session = apiClient.session ?? keyChainStorage.getSessionInfo(), !session.sid.isEmpty else {
            return .disconnected
        }
        do {
            try sessionOperations.commit {
                apiClient.updateSession(sid: session.sid, did: session.did)
            }
            if let currentConnection {
                try sessionOperations.commitState {
                    apiClient.updateConnection(type: currentConnection.type, url: currentConnection.url)
                }
            }
        } catch { return .disconnected }

        if currentConnection != nil {
            return await handleCurrentConnection(
                currentConnection,
                serverType: serverType
            )
        }

        return await handleUnreachableConnection(serverType: serverType)
    }

    func refreshQuickConnectEndpoint() async -> SynologyConnection? {
        if case let .updated(connection) = await runQuickConnectEndpointRefresh() {
            return connection
        }
        return nil
    }

    /// 调度器共享完整结果，使重发现后的明确 SID 失效能够交给登录流程处理。
    private func runQuickConnectEndpointRefresh() async -> QuickConnectEndpointRefreshOutcome {
        await optimizationScheduler.run { [weak self] in
            guard let self else {
                return .unavailable
            }
            return (try? await self.sessionOperations.perform { await self.performQuickConnectEndpointRefresh() }) ?? .unavailable
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
                    let isReachable = (try? await self.pingpong.pingpong(url: connection.url)) ?? false
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
        try await sessionOperations.perform { try await self.performSwitch(to: connection) }
    }

    private func performSwitch(to connection: SynologyConnection) async throws -> SynologyConnection {
        try await refreshSessionAndSaveConnection(connection)
        return connection
    }
}

private extension ConnectionManager {
    func resolveServerType(server: String) -> ServerType {
        QuickConnectUtils.isQuickConnectId(server: server) ? .quickConnectId : .customDomain
    }

    func handleCurrentConnection(
        _ currentConnection: SynologyConnection?,
        serverType: ServerType
    ) async -> ConnectionRecoveryDecision {
        switch await sessionValidator.validateCurrentSession() {
        case .valid:
            do {
                try sessionOperations.commit {
                    if let currentConnection {
                        eventPublisher.publishOnlineSessionValidated(
                            SynologyOnlineSessionValidatedEvent(connection: currentConnection, serverType: serverType)
                        )
                    }
                }
            } catch { return .disconnected }

            if serverType == .quickConnectId {
                await scheduleBackgroundQuickConnectEndpointRefresh(validatedConnection: currentConnection)
            }

            Logger.info("ConnectionManager#recoverConnection, reachable endpoint with valid session")
            return .connected
        case .invalidSession:
            Logger.info("ConnectionManager#recoverConnection, reachable endpoint but session invalid")
            return .requiresRelogin
        case .unreachable:
            return await handleUnreachableConnection(serverType: serverType)
        case .validationFailed:
            Logger.warn("ConnectionManager#recoverConnection, reachable endpoint but session validation failed")
            return .disconnected
        }
    }

    func handleUnreachableConnection(serverType: ServerType) async -> ConnectionRecoveryDecision {
        switch serverType {
        case .quickConnectId:
            switch await runQuickConnectEndpointRefresh() {
            case .updated:
                Logger.info("ConnectionManager#recoverConnection, refreshed QuickConnect endpoint")
                return .connected
            case .requiresRelogin:
                return .requiresRelogin
            case .unavailable:
                Logger.info("ConnectionManager#recoverConnection, QuickConnect refresh failed")
                return .disconnected
            }
        case .customDomain:
            Logger.info("ConnectionManager#recoverConnection, cached custom domain endpoint unreachable")
            return .disconnected
        }
    }

    func scheduleBackgroundQuickConnectEndpointRefresh(validatedConnection: SynologyConnection?) async {
        await optimizationScheduler.schedule { [weak self] in
            guard let self else {
                return .unavailable
            }
            return (try? await self.sessionOperations.performAfterCurrent { await self.performQuickConnectEndpointRefresh(validatedConnection: validatedConnection) }) ?? .unavailable
        }
    }

    func performQuickConnectEndpointRefresh(validatedConnection: SynologyConnection? = nil) async -> QuickConnectEndpointRefreshOutcome {
        guard let credentials = keyChainStorage.getCredentials(),
              QuickConnectUtils.isQuickConnectId(server: credentials.server)
        else {
            Logger.info("ConnectionManager#refreshQuickConnectEndpoint, skip non-QuickConnect credentials")
            return .unavailable
        }

        do {
            let previousConnection = restoreCurrentConnectionFromPersistence()
            let connection = try await quickConnectApi.getDeviceConnection(
                quickConnectId: credentials.server,
                usesHTTPS: credentials.usesHTTPS
            )

            // 恢复时已验证过的地址没有变化，无需再次刷新 API、校验 SID 或切换会话。
            if connection.url == validatedConnection?.url, connection.type == validatedConnection?.type {
                return .updated(connection)
            }

            // 地址发现不锁住普通请求；只在实际切换端点时协调会话写入。
            try await sessionOperations.perform {
                try await self.refreshSessionAndSaveConnection(connection)
                try self.sessionOperations.commit {
                    self.eventPublisher.publishQuickConnectEndpointOptimized(
                        SynologyQuickConnectEndpointOptimizedEvent(
                            updatedConnection: connection,
                            previousConnection: previousConnection
                        )
                    )
                }
            }
            Logger.info("ConnectionManager#refreshQuickConnectEndpoint, refreshed endpoint: \(connection.url)")
            return .updated(connection)
        } catch let error as SynologyError where error.isServerSessionExpired {
            Logger.info("ConnectionManager#refreshQuickConnectEndpoint, server confirmed expired session")
            return .requiresRelogin
        } catch {
            Logger.error("ConnectionManager#refreshQuickConnectEndpoint failed: \(error)")
            return .unavailable
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

        return SynologyConnection(type: type, url: persisted.url)
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

    /// 换地址先复用原 SID，校验成功才保存地址；弱网失败回滚但不清会话。
    /// 明确会话失效向上抛出，认证与凭据拒绝的终态统一交给登录流程处理。
    func refreshSessionAndSaveConnection(_ connection: SynologyConnection) async throws {
        guard let credentials = keyChainStorage.getCredentials() else {
            throw SynologyError.network(message: "Missing saved credentials")
        }
        apiInfoApi.selectServer(credentials.server)
        guard let previousSession = apiClient.session ?? keyChainStorage.getSessionInfo(), !previousSession.sid.isEmpty else {
            throw SynologyError.network(message: "Missing saved session")
        }

        let previousConnection = restoreCurrentConnectionFromPersistence()
        try sessionOperations.commit {
            apiClient.updateSession(sid: previousSession.sid, did: previousSession.did)
            apiClient.updateConnection(type: connection.type, url: connection.url)
        }

        do {
            try Task.checkCancellation()
            try await apiInfoApi.loadFromCacheOrRefresh()
            let outcome = await sessionValidator.validateCurrentSession()
            try Task.checkCancellation()

            switch outcome {
            case .valid:
                break
            case .invalidSession(let code):
                throw SynologyError.sessionExpired(code: code, message: "Server rejected session at selected endpoint")
            case .unreachable, .validationFailed:
                throw SynologyError.network(message: "Session validation failed at selected endpoint")
            }

            try sessionOperations.commitState {
                saveConnection(url: connection.url, type: connection.type)
            }
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

        sessionOperations.rollback { saveConnection(url: connection.url, type: connection.type) }
    }

    func rollbackSession(to session: (sid: String, did: String?)?) {
        sessionOperations.rollback {
            guard let session else {
                apiClient.clearSession()
                keyChainStorage.removeSessionInfo()
                return
            }
            apiClient.updateSession(sid: session.sid, did: session.did)
            keyChainStorage.saveSessionInfo(sid: session.sid, did: session.did)
        }
    }
}
