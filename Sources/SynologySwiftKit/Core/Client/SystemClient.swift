import Foundation

// MARK: - ConnectionClient

/// 连接相关客户端集合
/// Collection of connection-related clients
///
/// 当前包含：
/// - `quickConnect`: QuickConnect 解析客户端 / QuickConnect resolution client
/// - `ping`: Ping/Pong 延迟检测 / Ping/Pong latency checker
public final class ConnectionClient {
    /// QuickConnect 客户端，用于解析设备的可用连接地址
    /// QuickConnect client for resolving device connection endpoints
    public let quickConnect: QuickConnectClient

    /// PingPong 检测器，用于测试指定地址的可达性
    /// PingPong checker for testing reachability of a given URL
    let ping: PingPong

    init(quickConnect: QuickConnectClient, ping: PingPong) {
        self.quickConnect = quickConnect
        self.ping = ping
    }
}

// MARK: - SystemClient

/// 系统级客户端集合
/// Collection of system-level clients
///
/// 当前包含：
/// - `dsmInfo`: DSM 系统信息查询 / DSM system info query
/// - `encryption`: 加密信息获取 / Encryption info retrieval
/// - `connection`: 连接管理（QuickConnect + PingPong）/ Connection management
public final class SystemClient {
    /// DSM 系统信息客户端
    /// DSM system info client
    public let dsmInfo: DSMInfoClient

    /// 加密信息客户端（用于加密登录密码等）
    /// Encryption client (for encrypting login passwords, etc.)
    public let encryption: EncryptionClient

    /// 连接管理客户端
    /// Connection management client
    public let connection: ConnectionClient

    init(dsmInfo: DSMInfoClient, encryption: EncryptionClient, connection: ConnectionClient) {
        self.dsmInfo = dsmInfo
        self.encryption = encryption
        self.connection = connection
    }
}
