import Foundation

// MARK: - SynologyConnection

/// Synology 连接信息（连接类型 + 服务器地址）
/// Synology connection info (connection type + server URL)
public struct SynologyConnection: Sendable, Equatable {
    /// 连接类型（LAN / WAN / DDNS / Relay 等）
    /// Connection type (LAN / WAN / DDNS / Relay, etc.)
    public let type: ConnectionType

    /// 服务器地址（完整 URL，如 "https://192.168.1.x:5001"）
    /// Server URL (full URL, e.g. "https://192.168.1.x:5001")
    public let url: String

    public init(type: ConnectionType, url: String) {
        self.type = type
        self.url = url
    }
}

// MARK: - SynologySession

/// Synology 会话信息（SID + DID）
/// Synology session info (SID + DID)
public struct SynologySession: Sendable {
    /// 会话 ID（登录后服务器颁发）
    /// Session ID (issued by server after login)
    public let sid: String

    /// 设备 ID（可选，用于免密信任设备）
    /// Device ID (optional, used for trusted device login)
    public let did: String?

    public init(sid: String, did: String?) {
        self.sid = sid
        self.did = did
    }
}

// MARK: - SessionClient

/// 会话状态客户端（公开入口）
/// Public session state client
///
/// 负责查询和更新当前连接地址与会话信息（SID/DID）。
/// Responsible for querying and updating the current connection and session (SID/DID).
///
/// 使用示例 / Usage:
/// ```swift
/// let session = client.session.current
/// let connection = client.session.connection
/// client.session.clear()
/// ```
public final class SessionClient {
    private let connectionProvider: () -> SynologyConnection?
    private let sessionProvider: () -> SynologySession?
    private let connectionUpdater: (ConnectionType, String) -> Void
    private let sessionUpdater: (String, String?) -> Void
    private let sessionClearer: () -> Void

    init(connectionProvider: @escaping () -> SynologyConnection?,
         sessionProvider: @escaping () -> SynologySession?,
         connectionUpdater: @escaping (ConnectionType, String) -> Void,
         sessionUpdater: @escaping (String, String?) -> Void,
         sessionClearer: @escaping () -> Void) {
        self.connectionProvider = connectionProvider
        self.sessionProvider = sessionProvider
        self.connectionUpdater = connectionUpdater
        self.sessionUpdater = sessionUpdater
        self.sessionClearer = sessionClearer
    }

    /// 当前连接信息（连接类型 + 服务器地址）
    /// Current connection info (type + URL)
    public var connection: SynologyConnection? {
        connectionProvider()
    }

    /// 当前会话（SID + DID）；优先从内存读取，其次尝试从 Keychain 恢复
    /// Current session (SID + DID); reads from memory first, falls back to Keychain
    public var current: SynologySession? {
        sessionProvider()
    }

    /// 是否存在有效的会话
    /// Whether a valid session exists
    public var hasValidSession: Bool {
        current != nil
    }

    /// 更新连接地址
    /// Update connection URL
    /// - Parameters:
    ///   - type: 连接类型 / Connection type
    ///   - url: 服务器地址 / Server URL
    public func updateConnection(type: ConnectionType, url: String) {
        connectionUpdater(type, url)
    }

    /// 更新会话信息
    /// Update session info
    /// - Parameters:
    ///   - sid: 会话 ID / Session ID
    ///   - did: 设备 ID（可选）/ Device ID (optional)
    public func update(sid: String, did: String?) {
        sessionUpdater(sid, did)
    }

    /// 清除当前会话（同时清除内存和 Keychain）
    /// Clear the current session (memory and Keychain)
    public func clear() {
        sessionClearer()
    }
}
