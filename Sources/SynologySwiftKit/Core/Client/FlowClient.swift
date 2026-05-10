import Foundation

public final class UserLoginFlowClient {
    private let loginFlow: any SynologyUserLoginProviding

    init(loginFlow: any SynologyUserLoginProviding) {
        self.loginFlow = loginFlow
    }

    public func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword)
    }

    public func resume() -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login()
    }
}

public final class CheckDeviceConnectionFlowClient {
    private let connectionFlow: any CheckDeviceConnectionProviding

    init(connectionFlow: any CheckDeviceConnectionProviding) {
        self.connectionFlow = connectionFlow
    }

    public func check() -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus()
    }

    public func check(server: String, usesHTTPS: Bool) -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus(server: server, usesHTTPS: usesHTTPS)
    }
}

public final class QueryAllSongsFlowClient {
    private let queryFlow: any QueryAllSongsProviding

    init(queryFlow: any QueryAllSongsProviding) {
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
    public let userLogin: UserLoginFlowClient
    public let checkDeviceConnection: CheckDeviceConnectionFlowClient
    public let queryAllSongs: QueryAllSongsFlowClient

    init(userLogin: UserLoginFlowClient, checkDeviceConnection: CheckDeviceConnectionFlowClient, queryAllSongs: QueryAllSongsFlowClient) {
        self.userLogin = userLogin
        self.checkDeviceConnection = checkDeviceConnection
        self.queryAllSongs = queryAllSongs
    }
}
