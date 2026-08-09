//
//  KeyValueStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 键值存储协议（解耦 UserDefaults）
/// Key-value storage protocol (decouples from UserDefaults)
///
/// 抽象非敏感数据的持久化能力，默认由 `UserDefaultsStorage` 实现。
/// Abstracts non-sensitive data persistence; default implementation is `UserDefaultsStorage`.
public protocol KeyValueStorage {
    // MARK: - Read

    /// 读取字符串 / Read string value
    func string(forKey defaultName: String) -> String?
    /// 读取整数 / Read integer value
    func integer(forKey defaultName: String) -> Int
    /// 读取布尔值 / Read boolean value
    func bool(forKey defaultName: String) -> Bool
    /// 读取日期 / Read date value
    func date(forKey defaultName: String) -> Date?
    /// 读取原始 Data / Read raw Data value
    func data(forKey defaultName: String) -> Data?
    /// 读取 Decodable 对象（从 JSON Data 解码）/ Read Decodable object (decoded from JSON Data)
    func codable<T: Decodable>(forKey defaultName: String) -> T?

    // MARK: - Write

    /// 写入字符串 / Write string value
    func setString(_ value: String?, forKey defaultName: String)
    /// 写入整数 / Write integer value
    func setInteger(_ value: Int, forKey defaultName: String)
    /// 写入布尔值 / Write boolean value
    func setBool(_ value: Bool, forKey defaultName: String)
    /// 写入日期 / Write date value
    func setDate(_ value: Date?, forKey defaultName: String)
    /// 写入原始 Data / Write raw Data value
    func setData(_ value: Data?, forKey defaultName: String)
    /// 写入 Encodable 对象（以 JSON Data 存储）/ Write Encodable object (stored as JSON Data)
    func setCodable<T: Encodable>(_ value: T?, forKey defaultName: String)

    // MARK: - Remove

    /// 删除指定 key 的值 / Remove value for the given key
    func removeObject(forKey defaultName: String)
}

// MARK: - UserDefaults Implementation

/// 基于 UserDefaults 的键值存储实现
/// UserDefaults-backed key-value storage implementation
public final class UserDefaultsStorage: KeyValueStorage {
    private let userDefaults: UserDefaults

    /// 初始化存储（默认使用 `.standard` UserDefaults）
    /// Initialize storage (defaults to `.standard` UserDefaults)
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Read

    /// 读取字符串
    /// Read string value
    public func string(forKey defaultName: String) -> String? {
        userDefaults.string(forKey: defaultName)
    }

    /// 读取整数
    /// Read integer value
    public func integer(forKey defaultName: String) -> Int {
        userDefaults.integer(forKey: defaultName)
    }

    /// 读取布尔值
    /// Read boolean value
    public func bool(forKey defaultName: String) -> Bool {
        userDefaults.bool(forKey: defaultName)
    }

    /// 读取日期
    /// Read date value
    public func date(forKey defaultName: String) -> Date? {
        userDefaults.object(forKey: defaultName) as? Date
    }

    /// 读取原始 Data
    /// Read raw Data value
    public func data(forKey defaultName: String) -> Data? {
        userDefaults.data(forKey: defaultName)
    }

    // MARK: - Write

    /// 写入字符串（nil 时删除该 key）
    /// Write string value (removes key if nil)
    public func setString(_ value: String?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    /// 写入整数
    /// Write integer value
    public func setInteger(_ value: Int, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    /// 写入布尔值
    /// Write boolean value
    public func setBool(_ value: Bool, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    /// 写入日期（nil 时删除该 key）
    /// Write date value (removes key if nil)
    public func setDate(_ value: Date?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    /// 写入原始 Data（nil 时删除该 key）
    /// Write raw Data value (removes key if nil)
    public func setData(_ value: Data?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    /// 删除指定 key 的值
    /// Remove value for the given key
    public func removeObject(forKey defaultName: String) {
        userDefaults.removeObject(forKey: defaultName)
    }

    /// 写入 Encodable 对象（以 JSON Data 存储）
    /// Save an Encodable value as JSON data
    public func setCodable<T: Encodable>(_ value: T?, forKey defaultName: String) {
        guard let value else {
            removeObject(forKey: defaultName)
            return
        }

        guard let encoded = try? JSONEncoder().encode(value) else {
            Logger.error("[KeyValueStorage] Failed to encode data for \(defaultName)")
            return
        }
        setData(encoded, forKey: defaultName)
    }

    /// 读取 Decodable 对象（从 JSON Data 解码）
    /// Read a Decodable value from JSON data
    public func codable<T: Decodable>(forKey defaultName: String) -> T? {
        guard let data = data(forKey: defaultName) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - KeyValueStorageKeys

/// 非敏感键值存储的 Key 枚举
/// Key enum for non-sensitive key-value storage
///
/// 统一管理所有 `UserDefaultsStorage` 中使用的存储 Key，避免硬编码字符串散落各处。
/// Centralizes all `UserDefaultsStorage` keys to avoid hard-coded strings.
enum KeyValueStorageKeys {
    /// QuickConnect ID -> 已解析的服务器 URL
    /// QuickConnect ID -> resolved server URL
    case SYNOLOGY_SERVER_URL(String)

    /// DSM API 信息缓存
    /// DSM API info cache
    case DISK_STATION_API_INFO

    /// DSM API 信息最后更新时间
    /// DSM API info last update time
    case DISK_STATION_API_INFO_UPDATE_TIME

    /// AudioStation 系统信息缓存
    /// AudioStation system info cache
    case DISK_STATION_AUDIO_STATION_INFO

    /// AudioStation 系统信息最后更新时间
    /// AudioStation system info last update time
    case DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME

    /// 用户确认允许的 HTTPS 服务器证书指纹
    /// User-approved HTTPS server certificate fingerprints
    case APPROVED_SERVER_CERTIFICATES

    /// 对应的 UserDefaults key 字符串
    /// Corresponding UserDefaults key string
    var keyName: String {
        switch self {
        case let .SYNOLOGY_SERVER_URL(quickConnectId):
            return "SynologySwiftKit_SynologyServer_\(quickConnectId)"
        case .DISK_STATION_API_INFO:
            return "SynologySwiftKit_DiskStation_ApiInfo"
        case .DISK_STATION_API_INFO_UPDATE_TIME:
            return "SynologySwiftKit_DiskStation_ApiInfo_updateTime"
        case .DISK_STATION_AUDIO_STATION_INFO:
            return "SynologySwiftKit_DiskStation_AudioStation_Info"
        case .DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME:
            return "SynologySwiftKit_DiskStation_AudioStation_updateTime"
        case .APPROVED_SERVER_CERTIFICATES:
            return "SynologySwiftKit_ApprovedServerCertificates"
        }
    }
}
