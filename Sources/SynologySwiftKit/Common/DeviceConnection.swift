//
//  DeviceConnection.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/2.
//

import Foundation

/// 设备连接管理器 (Actor 保证并发安全)
public actor DeviceConnection: DeviceConnectionProviding {
    private var loginServer: (server: String, isEnableHttps: Bool)?
    private var connection: (type: ConnectionType, url: String)?
    private var session: (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)?

    /// 注入的存储依赖
    private let storage: KeyValueStorage

    /// Keychain 安全存储（用于凭据）
    /// Keychain secure storage (for credentials)
    private let keychainStorage: KeychainStorage

    private let ONE_WEEK_SECONDS = 604800
    private let ONE_YEAR_SECONDS = 31536000

    /// 初始化设备连接管理器
    /// Initialize device connection manager
    /// - Parameters:
    ///   - storage: 键值存储实现（默认 UserDefaults）/ Key-value storage implementation
    ///   - keychainStorage: Keychain 存储实现 / Keychain storage implementation
    public init(storage: KeyValueStorage = UserDefaultsStorage(), keychainStorage: KeychainStorage = KeychainStorage()) {
        self.storage = storage
        self.keychainStorage = keychainStorage
    }

    /// 获取当前URL
    public func getCurrentConnectionUrl() -> (type: ConnectionType, url: String)? {
        if let connection {
            return connection
        }

        if let connectionInfo = keychainStorage.getConnectionInfo(),
           let connectionType = ConnectionType(rawValue: connectionInfo.typeString) {
            let current = (connectionType, connectionInfo.url)
            connection = current
            Logger.info("[DeviceConnection]get connection-url from storage, connection url = \(current)")
            return current
        }

        Logger.warn("[DeviceConnection] Invalid or missing connection configuration. Logging out.")
        removeLoginSession()

        return nil
    }

    /// 获取当前用户名
    /// 获取当前用户名
    public func getSessionUsername() -> String? {
        // 从 Keychain Session Info 中获取
        return keychainStorage.getSessionInfo()?.username
    }

    /// 获取登录session
    public func getLoginSession() -> (sid: String, sidExpireAt: Date, did: String?, didExpireAt: Date?)? {
        if let session {
            return session
        }

        // 从 Keychain 读取 Session Info
        if let sessionInfo = keychainStorage.getSessionInfo() {
            // Keychain 中没有存储过期时间，为了兼容现有接口：
            // Session 过期时间只是为了本地判断，其实最终由 API 返回决定。
            // 我们可以设置一个较长的过期时间，或依赖 API 报错来重新登录。
            // 这里为了 logic continuity，重新计算过期时间（虽然不准确，但 Session 有效性最终由服务端决定）
            // 或者，我们在 KeychainStorage 中如果需要存过期时间，也得改结构。
            // 鉴于用户只要求存 sid/did，我们假设每次启动都在“有效期内”，直到 API 报错 4xx。
            
            let sidExpireAt = Date().addingTimeInterval(TimeInterval(ONE_WEEK_SECONDS))
            let didExpireAt = Date().addingTimeInterval(TimeInterval(ONE_YEAR_SECONDS))
            
            let current = (sessionInfo.sid, sidExpireAt, Optional(sessionInfo.did), Optional(didExpireAt))
            session = current
            return current
        }

        Logger.warn("[DeviceConnection]getLoginSession, session from storage is invalid")
        return nil
    }

    /// 获取登录服务器信息
    public func getLoginServer() -> (server: String, isEnableHttps: Bool)? {
        if let loginServer {
            return loginServer
        }

        if let prefs = keychainStorage.getLoginPreferences() {
            let current = (prefs.server, prefs.isEnableHttps)
            loginServer = current
            return current
        }

        return nil
    }

    /**
     update sid/did
     */
    public func updateLoginSession(username: String, sid: String, did: String?) {
        let sidExpireAt = addSecondsFromNow(seconds: ONE_WEEK_SECONDS)
        Logger.debug("update login session, sid will expire at: \(sidExpireAt)")

        if let did {
            let didExpireAt = addSecondsFromNow(seconds: ONE_YEAR_SECONDS)
            session = (sid, sidExpireAt, did, didExpireAt)
            
            // 持久化保存 Device ID (独立于 Session)
            // Persist Device ID (independent of session)
            keychainStorage.saveDeviceId(did)
        } else {
            session = (sid, sidExpireAt, nil, nil)
        }

        guard let currentSession = session else {
            return
        }
        Logger.debug("update login session, session: \(currentSession)")

        // 保存 Session 到 Keychain
        keychainStorage.saveSessionInfo(sid: sid, did: did ?? "", username: username)
        
        Logger.info("[DeviceConnection]updateLoginSession saved to storage (Keychain)")
    }

    /**
     保存当前的URL
     */
    public func updateCurrentConnectionUrl(type: ConnectionType, url: String) {
        connection = (type, url)

        // 保存 Connection Info 到 Keychain
        keychainStorage.saveConnectionInfo(url: url, typeString: type.rawValue)

        Logger.info("[DeviceConnection]update Connection to storage, url = \(url)")
    }

    /**
     removeLoginSession
     */
    public func removeLoginSession() {
        session = nil
        loginServer = nil
        connection = nil

        // 清除 Keychain 中的 Session 和 Connection 信息
        keychainStorage.removeSessionInfo()
        keychainStorage.removeConnectionInfo()
        keychainStorage.removeLoginPreferences()

        // 同时清除 Keychain 凭据
        // Also remove Keychain credentials
        keychainStorage.removeCredentials()

        Logger.info("[DeviceConnection]removeLoginSession from storage")
    }

    /**
     登录偏好
     */
    public func updateLoginPreferences(server: String, isEnableHttps: Bool) {
        loginServer = (server, isEnableHttps)

        // 保存 Login Preferences 到 Keychain
        keychainStorage.saveLoginPreferences(server: server, isEnableHttps: isEnableHttps)

        Logger.info("[DeviceConnection]updateLoginPreferences to storage")
    }

    /**
     removeCurrentConnectionUrl
     */
    public func removeCurrentConnectionUrl() {
        connection = nil
        connection = nil
        keychainStorage.removeConnectionInfo()
        Logger.info("[DeviceConnection]removeCurrentConnectionUrl from storage (Keychain)")
    }

    /**
     addSecondsFromNow
     */
    private func addSecondsFromNow(seconds: Int) -> Date {
        if let newDate = Calendar.current.date(byAdding: .second, value: seconds, to: Date()) {
            return newDate
        }
        return Date()
    }

    // MARK: - Credential Management

    /// 保存登录凭据到 Keychain
    /// Save login credentials to Keychain
    public func saveCredentials(server: String, username: String, password: String) {
        keychainStorage.saveCredentials(server: server, username: username, password: password)
    }

    /// 读取已保存的登录凭据
    /// Read saved login credentials
    public func getCredentials() -> (server: String, username: String, password: String)? {
        return keychainStorage.getCredentials()
    }

    /// 删除已保存的登录凭据
    /// Remove saved login credentials
    public func removeCredentials() {
        keychainStorage.removeCredentials()
    }
    
    /// 获取持久化的 Device ID (用于登录参数)
    /// Get persistent Device ID (for login parameters)
    public func getPersistentDeviceId() -> String? {
        keychainStorage.getDeviceId()
    }
    
    // MARK: - Device Name
    
    /// 获取设备名称 (持久化)
    /// Get Device Name (Persistent)
    public func getDeviceName() -> String {
        if let name = keychainStorage.getDeviceName() {
            return name
        }
        let name = UUID().uuidString
        keychainStorage.saveDeviceName(name)
        return name
    }
}
