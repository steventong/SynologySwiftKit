import Foundation

public final class AuthFlowClient {
    private let loginFlow: SynologyUserLogin

    init(loginFlow: SynologyUserLogin) {
        self.loginFlow = loginFlow
    }

    public func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword)
    }

    public func resume() -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login()
    }
}

public final class ConnectionFlowClient {
    private let connectionFlow: CheckDeviceConnection

    init(connectionFlow: CheckDeviceConnection) {
        self.connectionFlow = connectionFlow
    }

    public func check() -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus()
    }

    public func check(server: String, usesHTTPS: Bool) -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus(server: server, usesHTTPS: usesHTTPS)
    }
}

public final class LibraryFlowClient {
    private let queryFlow: QueryAllSongs

    init(queryFlow: QueryAllSongs) {
        self.queryFlow = queryFlow
    }

    public func queryTotalSongsCount() async -> Int {
        await queryFlow.queryTotalSongsCount()
    }

    public func queryAllSongs(batchSize: Int = 500, concurrency: Int = 3) -> AsyncStream<QueryAllSongsProgress> {
        queryFlow.queryAllSongs(batchSize: batchSize, concurrency: concurrency)
    }
}

public final class FlowClient {
    public let auth: AuthFlowClient
    public let connection: ConnectionFlowClient
    public let library: LibraryFlowClient

    init(auth: AuthFlowClient, connection: ConnectionFlowClient, library: LibraryFlowClient) {
        self.auth = auth
        self.connection = connection
        self.library = library
    }
}
