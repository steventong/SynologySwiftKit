import Foundation

// MARK: - UserLoginFlowClient

/// 用户登录流程客户端（公开入口）
/// Public entry point for the user login flow
///
/// 对外暴露 `SynologyUserLoginProviding` 的功能，屏蔽内部实现细节。
/// Exposes `SynologyUserLoginProviding` functionality while hiding implementation details.
public final class UserLoginFlowClient {
    private let loginFlow: any SynologyUserLoginProviding

    init(loginFlow: any SynologyUserLoginProviding) {
        self.loginFlow = loginFlow
    }

    /// 使用账号密码进行全量登录
    /// Perform full login with username and password
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名 / QuickConnect ID or custom domain
    ///   - usesHTTPS: 是否启用 HTTPS / Whether to use HTTPS
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - otpCode: 可选的 OTP 验证码 / Optional OTP code
    ///   - shouldSavePassword: 是否持久化保存密码（默认为 true）/ Whether to persist password (default: true)
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    public func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String? = nil, shouldSavePassword: Bool = true) -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login(server: server, usesHTTPS: usesHTTPS, username: username, password: password, otpCode: otpCode, shouldSavePassword: shouldSavePassword)
    }

    /// 使用 Keychain 中保存的凭据进行静默恢复登录
    /// Resume login silently using credentials saved in Keychain
    /// - Returns: AsyncStream 依次推送登录进度 / AsyncStream yielding login progress
    public func resume() -> AsyncStream<SynologyUserLoginProgress> {
        loginFlow.login()
    }
}

// MARK: - CheckDeviceConnectionFlowClient

/// 设备连接检查流程客户端（公开入口）
/// Public entry point for the device connection check flow
///
/// 对外暴露 `CheckDeviceConnectionProviding` 的功能，屏蔽内部实现细节。
/// Exposes `CheckDeviceConnectionProviding` functionality while hiding implementation details.
public final class CheckDeviceConnectionFlowClient {
    private let connectionFlow: any CheckDeviceConnectionProviding

    init(connectionFlow: any CheckDeviceConnectionProviding) {
        self.connectionFlow = connectionFlow
    }

    /// 使用 Keychain 中保存的服务器信息检查当前连接状态
    /// Check current connection status using server info saved in Keychain
    /// - Returns: AsyncStream 依次推送连接检查进度 / AsyncStream yielding connection check progress
    public func check() -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus()
    }

    /// 使用指定服务器检查连接状态
    /// Check connection status for a specific server
    /// - Parameters:
    ///   - server: QuickConnect ID 或自定义域名 / QuickConnect ID or custom domain
    ///   - usesHTTPS: 是否启用 HTTPS / Whether to use HTTPS
    /// - Returns: AsyncStream 依次推送连接检查进度 / AsyncStream yielding connection check progress
    public func check(server: String, usesHTTPS: Bool) -> AsyncStream<CheckDeviceConnectionProgress> {
        connectionFlow.checkConnectionStatus(server: server, usesHTTPS: usesHTTPS)
    }
}

// MARK: - QueryAllSongsFlowClient

/// 查询全部歌曲流程客户端（公开入口）
/// Public entry point for the query all songs flow
///
/// 对外暴露 `QueryAllSongsProviding` 的功能，屏蔽内部实现细节。
/// Exposes `QueryAllSongsProviding` functionality while hiding implementation details.
public final class QueryAllSongsFlowClient {
    private let queryFlow: any QueryAllSongsProviding

    init(queryFlow: any QueryAllSongsProviding) {
        self.queryFlow = queryFlow
    }

    /// 查询歌曲总数（异步，一次性结果）
    /// Query total songs count (async, single result)
    /// - Returns: 歌曲总数，失败返回 -1 / Total count, -1 on failure
    public func queryTotalSongsCount() async -> Int {
        await queryFlow.queryTotalSongsCount()
    }

    /// 批量查询所有歌曲
    /// Query all songs in batches
    /// - Parameters:
    ///   - batchSize: 每批次拉取数量（默认 500）/ Number of songs per batch (default: 500)
    ///   - concurrency: 并发任务数（默认 3）/ Number of concurrent tasks (default: 3)
    /// - Returns: AsyncStream 依次推送查询进度 / AsyncStream yielding query progress
    public func queryAllSongs(batchSize: Int = 500, concurrency: Int = 3) -> AsyncStream<QueryAllSongsProgress> {
        queryFlow.queryAllSongs(batchSize: batchSize, concurrency: concurrency)
    }
}

// MARK: - FlowClient

/// 流程客户端集合（统一入口）
/// Collection of flow clients (unified entry point)
///
/// 通过 `SynologyClient.flows` 访问所有业务流程：
/// Access all business flows through `SynologyClient.flows`:
/// - `userLogin`: 用户登录流程 / User login flow
/// - `checkDeviceConnection`: 设备连接检查流程 / Device connection check flow
/// - `queryAllSongs`: 批量歌曲查询流程 / Batch song query flow
public final class FlowClient {
    /// 用户登录流程
    /// User login flow
    public let userLogin: UserLoginFlowClient

    /// 设备连接检查流程
    /// Device connection check flow
    public let checkDeviceConnection: CheckDeviceConnectionFlowClient

    /// 批量歌曲查询流程
    /// Batch song query flow
    public let queryAllSongs: QueryAllSongsFlowClient

    init(userLogin: UserLoginFlowClient, checkDeviceConnection: CheckDeviceConnectionFlowClient, queryAllSongs: QueryAllSongsFlowClient) {
        self.userLogin = userLogin
        self.checkDeviceConnection = checkDeviceConnection
        self.queryAllSongs = queryAllSongs
    }
}
