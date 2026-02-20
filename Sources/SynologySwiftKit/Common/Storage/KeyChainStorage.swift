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

    /// 初始化 Keychain 存储
    /// Initialize Keychain storage
    /// - Parameter service: 服务标识符 / Service identifier
    public init(service: String = "com.synologyswiftkit.credentials") {
        self.service = service
    }

    // MARK: - Credentials Management

    /// 保存登录凭据到 Keychain
    /// Save login credentials to Keychain
    /// - Parameters:
    ///   - server: 服务器地址（QuickConnect ID 或自定义域名）/ Server address
    ///   - username: 用户名 / Username
    ///   - password: 密码 / Password
    ///   - isEnableHttps: 是否启用 HTTPS (可选) / Enable HTTPS (optional)
    public func saveCredentials(server: String, username: String, password: String, isEnableHttps: Bool? = nil) {
        let credentials = CredentialData(server: server, username: username, password: password, isEnableHttps: isEnableHttps)
        guard let data = try? JSONEncoder().encode(credentials) else {
            Logger.error("[KeychainStorage] Failed to encode credentials")
            return
        }

        // 先删除旧的凭据
        // Remove existing credentials first
        removeCredentials()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "synology_credentials",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            Logger.info("[KeychainStorage] Credentials saved successfully")
        } else {
            Logger.error("[KeychainStorage] Failed to save credentials, status: \(status)")
        }
    }

    /// 从 Keychain 读取已保存的凭据
    /// Read saved credentials from Keychain
    /// - Returns: 凭据元组（server, username, password, isEnableHttps），如果不存在则返回 nil
    public func getCredentials() -> (server: String, username: String, password: String, isEnableHttps: Bool?)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "synology_credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(CredentialData.self, from: data)
        else {
            if status != errSecItemNotFound {
                Logger.error("[KeychainStorage] Failed to read credentials, status: \(status)")
            }
            return nil
        }

        return (credentials.server, credentials.username, credentials.password, credentials.isEnableHttps)
    }

    // MARK: - Session Info

    /// 保存 Session 信息
    /// Save session info
    func saveSessionInfo(sid: String, did: String?) {
        let account = "synology_session_info"
        let sessionInfo = SessionInfoData(sid: sid, did: did ?? "")

        guard let data = try? JSONEncoder().encode(sessionInfo) else {
            Logger.error("[KeychainStorage] Failed to encode session info")
            return
        }

        save(account: account, rawData: data)
    }

    /// 获取 Session 信息
    /// Get session info
    func getSessionInfo() -> (sid: String, did: String)? {
        let account = "synology_session_info"

        // Try reading as SessionInfoData (new format)
        if let data = readRaw(account: account),
           let sessionInfo = try? JSONDecoder().decode(SessionInfoData.self, from: data) {
            return (sessionInfo.sid, sessionInfo.did)
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
        let account = "synology_session_info"
        delete(account: account)
    }

    // MARK: - Device ID (Persistent)

    /// 保存设备 ID (持久化，不随登出清除)
    /// Save Device ID (Persistent, not cleared on logout)
    func saveDeviceId(_ did: String) {
        let account = "synology_device_id"
        let data: [String: String] = ["did": did]
        save(account: account, data: data)
    }

    /// 获取设备 ID
    /// Get Device ID
    func getDeviceId() -> String? {
        let account = "synology_device_id"
        guard let data: [String: String] = read(account: account) else { return nil }
        return data["did"]
    }

    // MARK: - Device Name

    /// 保存设备名称 (持久化)
    /// Save Device Name (Persistent)
    func saveDeviceName(_ name: String) {
        let account = "synology_device_name"
        let data: [String: String] = ["name": name]
        save(account: account, data: data)
    }

    /// 获取设备名称
    /// Get Device Name
    func getDeviceName() -> String? {
        let account = "synology_device_name"
        guard let data: [String: String] = read(account: account) else { return nil }
        return data["name"]
    }

    // MARK: - Connection URL

    /// 保存连接地址信息
    /// Save connection URL info
    func saveConnectionInfo(url: String, typeString: String) {
        let account = "synology_connection_info"
        let data: [String: String] = [
            "url": url,
            "type": typeString,
        ]
        save(account: account, data: data)
    }

    /// 获取连接地址信息
    /// Get connection URL info
    func getConnectionInfo() -> (url: String, typeString: String)? {
        let account = "synology_connection_info"
        guard let data: [String: String] = read(account: account),
              let url = data["url"],
              let typeString = data["type"] else {
            return nil
        }
        return (url, typeString)
    }

    /// 移除连接地址信息
    /// Remove connection URL info
    func removeConnectionInfo() {
        delete(account: accountName(for: "synology_connection_info"))
    }

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

    private func read<T: Decodable>(account: String) -> T? {
        guard let data = readRaw(account: account) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save(account: String, rawData: Data) {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceInfo(for: account),
            kSecAttrAccount as String: account,
            kSecValueData as String: rawData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.error("[KeychainStorage] Failed to save \(account), status: \(status)")
        }
    }

    private func readRaw(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceInfo(for: account),
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
            kSecAttrService as String: serviceInfo(for: account),
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func serviceInfo(for account: String) -> String {
        return "com.synologyswiftkit.storage"
    }

    private func accountName(for key: String) -> String {
        return key
    }

    /// 从 Keychain 删除凭据
    /// Remove credentials from Keychain
    public func removeCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "synology_credentials",
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            Logger.info("[KeychainStorage] Credentials removed")
        } else {
            Logger.error("[KeychainStorage] Failed to remove credentials, status: \(status)")
        }
    }
}

// 扩展现有的 saveCredentials 使用新的通用方法?
// 为了保持兼容性，先保留原有代码，重构一下。

// MARK: - CredentialData

/// 凭据数据模型（用于 JSON 编解码）
/// Credential data model (for JSON encoding/decoding)
private struct CredentialData: Codable {
    let server: String
    let username: String
    let password: String
    let isEnableHttps: Bool?
}

/// Session 信息数据模型
/// Session info data model
private struct SessionInfoData: Codable {
    let sid: String
    let did: String
}
