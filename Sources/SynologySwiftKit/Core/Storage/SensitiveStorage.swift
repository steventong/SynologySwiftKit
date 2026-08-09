import Foundation

// MARK: - CredentialStorage

/// 凭据存储协议（账号密码）
/// Protocol for credential storage (username and password)
public protocol CredentialStorage: AnyObject, Sendable {
    /// 保存登录凭据
    /// Save login credentials
    func saveCredentials(server: String, username: String, password: String, usesHTTPS: Bool)

    /// 获取已保存的登录凭据，不存在时返回 nil
    /// Get saved login credentials, returns nil if not found
    func getCredentials() -> SynologyCredentials?

    /// 删除已保存的登录凭据
    /// Remove saved login credentials
    func removeCredentials()
}

// MARK: - LoginAccountHistoryStorage

/// 历史登录账号存储协议。
/// Protocol for storing successfully authenticated accounts.
public protocol LoginAccountHistoryStorage: AnyObject, Sendable {
    /// 将成功登录的账号保存到历史记录；相同服务器和用户名的记录会被替换并置顶。
    /// Save a successfully authenticated account; duplicate server and username pairs are replaced and moved first.
    func saveLoginAccountToHistory(server: String, username: String, password: String)

    /// 获取历史登录账号，按最近登录时间倒序排列。
    /// Get login account history ordered from most to least recent.
    func getLoginAccountHistory() -> [SynologyLoginAccountHistoryItem]

    /// 删除指定历史登录账号。
    /// Remove a login account history item.
    func removeLoginAccountFromHistory(id: UUID)
}

// MARK: - SessionStorage

/// 会话存储协议（SID + DID）
/// Protocol for session storage (SID + DID)
public protocol SessionStorage: AnyObject, Sendable {
    /// 保存会话信息
    /// Save session info
    func saveSessionInfo(sid: String, did: String?)

    /// 获取已保存的会话信息，不存在时返回 nil
    /// Get saved session info, returns nil if not found
    func getSessionInfo() -> (sid: String, did: String?)?

    /// 删除已保存的会话信息
    /// Remove saved session info
    func removeSessionInfo()
}

// MARK: - ConnectionStorage

/// 连接地址存储协议
/// Protocol for connection URL storage
public protocol ConnectionStorage: AnyObject, Sendable {
    /// 保存连接地址信息
    /// Save connection URL info
    func saveConnectionInfo(url: String, typeString: String)

    /// 获取已保存的连接地址，不存在时返回 nil
    /// Get saved connection URL, returns nil if not found
    func getConnectionInfo() -> (url: String, typeString: String)?

    /// 删除已保存的连接地址
    /// Remove saved connection URL
    func removeConnectionInfo()
}

// MARK: - DeviceIdentityStorage

/// 设备身份存储协议（DID + 设备名）
/// Protocol for device identity storage (DID + device name)
public protocol DeviceIdentityStorage: AnyObject, Sendable {
    /// 保存设备身份信息（持久化，不随登出清除）
    /// Save device identity (persistent, not cleared on logout)
    func saveDeviceInfo(_ did: String, _ name: String)

    /// 获取已保存的设备身份，不存在时返回 nil
    /// Get saved device identity, returns nil if not found
    func getDeviceInfo() -> (String, String)?
}

// MARK: - SensitiveStorage

/// 敏感信息存储组合协议
/// Composite protocol for sensitive storage
///
/// 组合了凭据、历史账号、会话、连接地址、设备身份五类敏感数据的存取能力。
/// Combines credential, account history, session, connection, and device identity storage capabilities.
public typealias SensitiveStorage = CredentialStorage
    & LoginAccountHistoryStorage
    & SessionStorage
    & ConnectionStorage
    & DeviceIdentityStorage
