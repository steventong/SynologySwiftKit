//
//  KeychainStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation
import Security

// MARK: - KeychainStorage

/// Keychain 安全存储（用于保存账号密码等敏感信息）
/// Keychain secure storage for saving credentials and other sensitive data
public final class KeyChainStorage: @unchecked Sendable {
    /// Keychain 服务名称前缀
    /// Keychain service name prefix
    private let service: String

    private let key_credentials = "synology_credentials"
    private let key_session = "synology_session_info"
    private let key_connection = "synology_connection_info"
    private let key_device = "synology_device_info"

    /// 初始化 Keychain 存储
    /// Initialize Keychain storage
    /// - Parameter service: 服务标识符 / Service identifier
    public init(service: String = "com.synologyswiftkit.keychain") {
        self.service = service
    }

    // MARK: - Credentials Management

    /// 保存登录凭据到 Keychain
    /// Save login credentials to Keychain
    /// - Parameters:
    ///   - server: 服务器地址（QuickConnect ID 或自定义域名）/ Server address
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - usesHTTPS: 是否启用 HTTPS (可选) / Enable HTTPS (optional)
    public func saveCredentials(server: String, username: String, password: String, usesHTTPS: Bool) {
        let credentials: [String: String] = ["server": server,
                                             "username": username,
                                             "password": password,
                                             "usesHTTPS": usesHTTPS ? "Y" : "N"]

        save(account: key_credentials, data: credentials)
    }

    /// 从 Keychain 读取已保存的凭据
    /// Read saved credentials from Keychain
    /// - Returns: 凭据对象，如果不存在则返回 nil
    public func getCredentials() -> SynologyCredentials? {
        if let data: [String: String] = read(account: key_credentials),
           let server = data["server"],
           let username = data["username"],
           let password = data["password"]
        {
            let usesHTTPS = data["usesHTTPS"] == "Y" || data["isEnableHttps"] == "Y"
            return SynologyCredentials(server: server, username: username, password: password, usesHTTPS: usesHTTPS)
        }

        return nil
    }

    /// 从 Keychain 删除凭据
    /// Remove credentials from Keychain
    public func removeCredentials() {
        delete(account: key_credentials)
    }

    // MARK: - Session Info

    /// 保存 Session 信息
    /// Save session info
    func saveSessionInfo(sid: String, did: String?) {
        let sessionInfo: [String: String] = ["sid": sid, "did": did ?? ""]
        save(account: key_session, data: sessionInfo)
    }

    /// 获取 Session 信息
    /// Get session info
    func getSessionInfo() -> (sid: String, did: String)? {
        // Try reading as SessionInfoData (new format)
        if let data: [String: String] = read(account: key_session),
           let sid = data["sid"], let did = data["did"] {
            return (sid, did)
        }

        // Fallback: Try reading as [String: String] (old format) for migration compatibility?
        // Actually, let's just ignore old data or try to read it.
        // Given this is a library, maybe strict migration is better if we want to force cleanup.
        // But user data loss (session logout) is acceptable for update.
        return nil
    }

    /// 移除 Session 信息
    /// Remove session info
    func removeSessionInfo() {
        delete(account: key_session)
    }

    // MARK: - Device ID (Persistent)

    /// 保存设备 ID (持久化，不随登出清除)
    /// Save Device ID (Persistent, not cleared on logout)
    func saveDeviceInfo(_ did: String, _ name: String) {
        let data: [String: String] = ["did": did, "name": name]
        save(account: key_device, data: data)
    }

    /// 获取设备 ID
    /// Get Device ID
    func getDeviceInfo() -> (String, String)? {
        if let data: [String: String] = read(account: key_device),
           let did = data["did"], let name = data["name"] {
            return (did, name)
        }
        return nil
    }

    // MARK: - Connection URL

    /// 保存连接地址信息
    /// Save connection URL info
    func saveConnectionInfo(url: String, typeString: String) {
        let data: [String: String] = ["url": url, "type": typeString]
        save(account: key_connection, data: data)
    }

    /// 获取连接地址信息
    /// Get connection URL info
    func getConnectionInfo() -> (url: String, typeString: String)? {
        if let data: [String: String] = read(account: key_connection),
           let url = data["url"], let typeString = data["type"] {
            return (url, typeString)
        }
        return nil
    }

    /// 移除连接地址信息
    /// Remove connection URL info
    func removeConnectionInfo() {
        delete(account: key_connection)
    }
}

extension KeyChainStorage {
    // MARK: - API Info Cache (Optional, maybe keep in UserDefaults for performance?)

    // API Info is not sensitive and accessed frequently. UserDefaults/Memory is better.
    // User only asked for sid/did/quickconnectid.

    // MARK: - Helper Methods

    private func save<T: Encodable>(account: String, data: T) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            Logger.error("[KeychainStorage] Failed to encode data for \(account)")
            return
        }
        save(account: account, rawData: encoded)
    }

    private func save(account: String, rawData: Data) {
        // delete data
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: rawData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.error("[KeychainStorage] Failed to save \(account), status: \(status)")
        }
    }

    private func read<T: Decodable>(account: String) -> T? {
        guard let data = readRaw(account: account) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func readRaw(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        return nil
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
