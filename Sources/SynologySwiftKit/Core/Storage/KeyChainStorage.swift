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
public final class KeyChainStorage: SensitiveStorage, @unchecked Sendable {
    /// Keychain 服务名称前缀
    /// Keychain service name prefix
    private let service: String

    /// 使用现代 Data Protection Keychain，避免 macOS 旧式钥匙串的 ACL 授权弹窗
    /// Uses the modern Data Protection Keychain instead of the legacy macOS ACL model
    private let usesDataProtectionKeychain: Bool
    
    private let unifiedAccount = "synology_secure_store"

    /// 串行化所有 Keychain 访问：并发 SecItem* 调用会在 legacy keychain 层死锁，
    /// 且 updateSecureStore 的读-改-写必须原子执行，否则并发更新会互相覆盖
    /// Serializes all Keychain access: concurrent SecItem* calls can deadlock in the
    /// legacy keychain layer, and updateSecureStore's read-modify-write must be atomic
    /// or concurrent updates overwrite each other
    private let lock = NSRecursiveLock()

    /// 初始化 Keychain 存储
    /// Initialize Keychain storage
    /// - Parameter service: 服务标识符 / Service identifier
    public convenience init(service: String = "com.synologyswiftkit.keychain") {
        self.init(service: service, usesDataProtectionKeychain: true)
    }

    init(service: String, usesDataProtectionKeychain: Bool) {
        self.service = service
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
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
        let credentials = SynologyCredentials(server: server, username: username, password: password, usesHTTPS: usesHTTPS)
        updateSecureStore {
            $0.credentials = credentials
        }
    }

    /// 从 Keychain 读取已保存的凭据
    /// Read saved credentials from Keychain
    /// - Returns: 凭据对象，如果不存在则返回 nil
    public func getCredentials() -> SynologyCredentials? {
        secureStore().credentials
    }

    /// 从 Keychain 删除凭据
    /// Remove credentials from Keychain
    public func removeCredentials() {
        updateSecureStore {
            $0.credentials = nil
        }
    }

    // MARK: - Session Info

    /// 保存 Session 信息
    /// Save session info
    public func saveSessionInfo(sid: String, did: String?) {
        let sessionInfo = SynologySessionInfo(sid: sid, did: did)
        updateSecureStore {
            $0.sessionInfo = sessionInfo
        }
    }

    /// 获取 Session 信息
    /// Get session info
    public func getSessionInfo() -> (sid: String, did: String?)? {
        guard let sessionInfo = secureStore().sessionInfo else {
            return nil
        }
        return (sessionInfo.sid, sessionInfo.did)
    }

    /// 移除 Session 信息
    /// Remove session info
    public func removeSessionInfo() {
        updateSecureStore {
            $0.sessionInfo = nil
        }
    }

    // MARK: - Device ID (Persistent)

    /// 保存设备 ID (持久化，不随登出清除)
    /// Save Device ID (Persistent, not cleared on logout)
    public func saveDeviceInfo(_ did: String, _ name: String) {
        let data = SynologyDeviceInfo(did: did, name: name)
        updateSecureStore {
            $0.deviceInfo = data
        }
    }

    /// 获取设备 ID
    /// Get Device ID
    public func getDeviceInfo() -> (String, String)? {
        guard let data = secureStore().deviceInfo else {
            return nil
        }
        return (data.did, data.name)
    }

    // MARK: - Connection URL

    /// 保存连接地址信息
    /// Save connection URL info
    public func saveConnectionInfo(url: String, typeString: String) {
        let data = SynologyConnectionInfo(url: url, typeString: typeString)
        updateSecureStore {
            $0.connectionInfo = data
        }
    }

    /// 获取连接地址信息
    /// Get connection URL info
    public func getConnectionInfo() -> (url: String, typeString: String)? {
        guard let data = secureStore().connectionInfo else {
            return nil
        }
        return (data.url, data.typeString)
    }

    /// 移除连接地址信息
    /// Remove connection URL info
    public func removeConnectionInfo() {
        updateSecureStore {
            $0.connectionInfo = nil
        }
    }
}

extension KeyChainStorage {
    func setCodable<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            removeValue(forKey: key)
            return
        }
        save(account: key, data: value)
    }

    func codable<T: Decodable>(forKey key: String) -> T? {
        read(account: key)
    }

    func removeValue(forKey key: String) {
        delete(account: key)
    }

    private func secureStore() -> SecureStorePayload {
        read(account: unifiedAccount) ?? SecureStorePayload()
    }

    private func updateSecureStore(_ mutate: (inout SecureStorePayload) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var store = secureStore()
        mutate(&store)

        if store.hasContent {
            save(account: unifiedAccount, data: store)
        } else {
            delete(account: unifiedAccount)
        }
    }

    // MARK: - API Info Cache (Optional, maybe keep in UserDefaults for performance?)

    // API Info is not sensitive and accessed frequently. UserDefaults/Memory is better.
    // User only asked for sid/did/quickconnectid.

    // MARK: - Helper Methods

    /// 将 Encodable 对象序列化为 JSON Data 后存入 Keychain
    /// Serialize Encodable object as JSON Data and save to Keychain
    private func save<T: Encodable>(account: String, data: T) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            Logger.error("[KeychainStorage] Failed to encode data for \(account)")
            return
        }
        save(account: account, rawData: encoded)
    }

    /// 将原始 Data 存入 Keychain（先删除旧值再写入）
    /// Save raw Data to Keychain (delete existing value first)
    /// - Note: 使用 `kSecAttrAccessibleAfterFirstUnlock` 确保后台访问可用 / Uses `kSecAttrAccessibleAfterFirstUnlock` for background access
    private func save(account: String, rawData: Data) {
        lock.lock()
        defer { lock.unlock() }

        // delete data
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: rawData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: usesDataProtectionKeychain,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.error("[KeychainStorage] Failed to save \(account), status: \(status)")
        }
    }

    /// 从 Keychain 读取并反序列化 Decodable 对象
    /// Read and deserialize a Decodable object from Keychain
    private func read<T: Decodable>(account: String) -> T? {
        guard let data = readRaw(account: account) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 从 Keychain 读取原始 Data
    /// Read raw Data from Keychain
    private func readRaw(account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: usesDataProtectionKeychain,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            return data
        }
        return nil
    }

    /// 从 Keychain 删除指定条目
    /// Delete a specific item from Keychain
    private func delete(account: String) {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: usesDataProtectionKeychain,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct SecureStorePayload: Codable {
    var credentials: SynologyCredentials?
    var sessionInfo: SynologySessionInfo?
    var connectionInfo: SynologyConnectionInfo?
    var deviceInfo: SynologyDeviceInfo?

    var hasContent: Bool {
        credentials != nil || sessionInfo != nil || connectionInfo != nil || deviceInfo != nil
    }
}
