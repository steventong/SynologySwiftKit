import Foundation

/// 标记需要优先走 Keychain 的敏感值类型
/// Marker protocol for values that should prefer Keychain storage
public protocol SensitiveStorageValue: Codable, Sendable {}

/// 存储后端选择
/// Storage backend selection
public enum StorageBackend: Sendable {
    case automatic
    case userDefaults
    case keychain
}

/// kit 内统一的存储服务入口
/// Unified storage service entry point for the kit
public final class StorageService: KeyValueStorage, SensitiveStorage, @unchecked Sendable {
    private let keyValueStorage: KeyValueStorage
    private let keyChainStorage: KeyChainStorage

    public init(
        keyValueStorage: KeyValueStorage = UserDefaultsStorage(),
        keyChainStorage: KeyChainStorage = KeyChainStorage()
    ) {
        self.keyValueStorage = keyValueStorage
        self.keyChainStorage = keyChainStorage
    }

    /// 写入任意 Codable 值；默认根据值类型自动选择存储后端
    /// Persist any Codable value; automatically chooses backend by value type by default
    public func setValue<T: Codable & Sendable>(_ value: T?, forKey key: String, storage: StorageBackend = .automatic) {
        switch resolvedBackend(for: T.self, preferred: storage) {
        case .automatic:
            assertionFailure("Storage backend resolution must not return .automatic")
        case .userDefaults:
            keyValueStorage.setCodable(value, forKey: key)
        case .keychain:
            keyChainStorage.setCodable(value, forKey: key)
        }
    }

    /// 读取任意 Codable 值；默认根据值类型自动选择存储后端
    /// Read any Codable value; automatically chooses backend by value type by default
    public func value<T: Codable & Sendable>(forKey key: String, as type: T.Type = T.self, storage: StorageBackend = .automatic) -> T? {
        switch resolvedBackend(for: type, preferred: storage) {
        case .automatic:
            assertionFailure("Storage backend resolution must not return .automatic")
            return nil
        case .userDefaults:
            return keyValueStorage.codable(forKey: key)
        case .keychain:
            return keyChainStorage.codable(forKey: key)
        }
    }

    /// 删除任意值；默认根据值类型自动选择存储后端
    /// Remove any value; automatically chooses backend by value type by default
    public func removeValue<T: Codable & Sendable>(forKey key: String, as type: T.Type = T.self, storage: StorageBackend = .automatic) {
        switch resolvedBackend(for: type, preferred: storage) {
        case .automatic:
            assertionFailure("Storage backend resolution must not return .automatic")
        case .userDefaults:
            keyValueStorage.removeObject(forKey: key)
        case .keychain:
            keyChainStorage.removeValue(forKey: key)
        }
    }

    private func resolvedBackend<T: Codable & Sendable>(for type: T.Type, preferred: StorageBackend) -> StorageBackend {
        if preferred != .automatic {
            return preferred
        }
        return type is any SensitiveStorageValue.Type ? .keychain : .userDefaults
    }
}

extension StorageService {
    public func string(forKey defaultName: String) -> String? {
        keyValueStorage.string(forKey: defaultName)
    }

    public func integer(forKey defaultName: String) -> Int {
        keyValueStorage.integer(forKey: defaultName)
    }

    public func bool(forKey defaultName: String) -> Bool {
        keyValueStorage.bool(forKey: defaultName)
    }

    public func date(forKey defaultName: String) -> Date? {
        keyValueStorage.date(forKey: defaultName)
    }

    public func data(forKey defaultName: String) -> Data? {
        keyValueStorage.data(forKey: defaultName)
    }

    public func codable<T: Decodable>(forKey defaultName: String) -> T? {
        keyValueStorage.codable(forKey: defaultName)
    }

    public func setString(_ value: String?, forKey defaultName: String) {
        keyValueStorage.setString(value, forKey: defaultName)
    }

    public func setInteger(_ value: Int, forKey defaultName: String) {
        keyValueStorage.setInteger(value, forKey: defaultName)
    }

    public func setBool(_ value: Bool, forKey defaultName: String) {
        keyValueStorage.setBool(value, forKey: defaultName)
    }

    public func setDate(_ value: Date?, forKey defaultName: String) {
        keyValueStorage.setDate(value, forKey: defaultName)
    }

    public func setData(_ value: Data?, forKey defaultName: String) {
        keyValueStorage.setData(value, forKey: defaultName)
    }

    public func setCodable<T: Encodable>(_ value: T?, forKey defaultName: String) {
        keyValueStorage.setCodable(value, forKey: defaultName)
    }

    public func removeObject(forKey defaultName: String) {
        keyValueStorage.removeObject(forKey: defaultName)
    }
}

extension StorageService {
    public func saveCredentials(server: String, username: String, password: String, usesHTTPS: Bool) {
        let credentials = SynologyCredentials(server: server, username: username, password: password, usesHTTPS: usesHTTPS)
        setValue(credentials, forKey: SensitiveStorageKeys.credentials.rawValue)
    }

    public func getCredentials() -> SynologyCredentials? {
        value(forKey: SensitiveStorageKeys.credentials.rawValue, as: SynologyCredentials.self)
    }

    public func removeCredentials() {
        removeValue(forKey: SensitiveStorageKeys.credentials.rawValue, as: SynologyCredentials.self)
    }

    public func saveLoginAccountToHistory(server: String, username: String, password: String) {
        keyChainStorage.saveLoginAccountToHistory(
            server: server,
            username: username,
            password: password
        )
    }

    public func getLoginAccountHistory() -> [SynologyLoginAccountHistoryItem] {
        keyChainStorage.getLoginAccountHistory()
    }

    public func removeLoginAccountFromHistory(id: UUID) {
        keyChainStorage.removeLoginAccountFromHistory(id: id)
    }

    public func saveSessionInfo(sid: String, did: String?) {
        let sessionInfo = SynologySessionInfo(sid: sid, did: did)
        setValue(sessionInfo, forKey: SensitiveStorageKeys.sessionInfo.rawValue)
    }

    public func getSessionInfo() -> (sid: String, did: String?)? {
        guard let info: SynologySessionInfo = value(forKey: SensitiveStorageKeys.sessionInfo.rawValue) else {
            return nil
        }
        return (info.sid, info.did)
    }

    public func removeSessionInfo() {
        removeValue(forKey: SensitiveStorageKeys.sessionInfo.rawValue, as: SynologySessionInfo.self)
    }

    public func saveConnectionInfo(url: String, typeString: String) {
        let info = SynologyConnectionInfo(url: url, typeString: typeString)
        setValue(info, forKey: SensitiveStorageKeys.connectionInfo.rawValue)
    }

    public func getConnectionInfo() -> (url: String, typeString: String)? {
        guard let info: SynologyConnectionInfo = value(forKey: SensitiveStorageKeys.connectionInfo.rawValue) else {
            return nil
        }
        return (info.url, info.typeString)
    }

    public func removeConnectionInfo() {
        removeValue(forKey: SensitiveStorageKeys.connectionInfo.rawValue, as: SynologyConnectionInfo.self)
    }

    public func saveDeviceInfo(_ did: String, _ name: String) {
        let info = SynologyDeviceInfo(did: did, name: name)
        setValue(info, forKey: SensitiveStorageKeys.deviceInfo.rawValue)
    }

    public func getDeviceInfo() -> (String, String)? {
        guard let info: SynologyDeviceInfo = value(forKey: SensitiveStorageKeys.deviceInfo.rawValue) else {
            return nil
        }
        return (info.did, info.name)
    }
}

private enum SensitiveStorageKeys: String {
    case credentials = "synology_credentials"
    case sessionInfo = "synology_session_info"
    case connectionInfo = "synology_connection_info"
    case deviceInfo = "synology_device_info"
}
