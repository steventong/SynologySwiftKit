//
//  KeyValueStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 键值存储协议（解耦 UserDefaults）
/// Key-Value Storage Protocol (Decouple UserDefaults)
public protocol KeyValueStorage {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func bool(forKey defaultName: String) -> Bool
    func object(forKey defaultName: String) -> Any?
    func data(forKey defaultName: String) -> Data?
    func codable<T: Decodable>(forKey defaultName: String) -> T?

    func set(_ value: Any?, forKey defaultName: String)
    func set<T: Encodable>(_ value: T?, forKey defaultName: String)

    func removeObject(forKey defaultName: String)

    // 注意：Actor 环境下不再需要显示调用 synchronize，
    // 具体实现应自己处理持久化策略。
}

// MARK: - UserDefaults Implementation

/// 基于 UserDefaults 的存储实现
public final class UserDefaultsStorage: KeyValueStorage {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func string(forKey defaultName: String) -> String? {
        userDefaults.string(forKey: defaultName)
    }

    public func integer(forKey defaultName: String) -> Int {
        userDefaults.integer(forKey: defaultName)
    }

    public func bool(forKey defaultName: String) -> Bool {
        userDefaults.bool(forKey: defaultName)
    }

    public func object(forKey defaultName: String) -> Any? {
        userDefaults.object(forKey: defaultName)
    }

    public func data(forKey defaultName: String) -> Data? {
        userDefaults.data(forKey: defaultName)
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        userDefaults.set(value, forKey: defaultName)
    }

    public func removeObject(forKey defaultName: String) {
        userDefaults.removeObject(forKey: defaultName)
    }

    /// 写入 Encodable 对象（以 JSON Data 存储）
    /// Save an Encodable value as JSON data
    public func set<T: Encodable>(_ value: T?, forKey defaultName: String) {
        guard let encoded = try? JSONEncoder().encode(value) else {
            Logger.error("[KeyValueStorage] Failed to encode data for \(defaultName)")
            return
        }
        userDefaults.set(encoded, forKey: defaultName)
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

enum KeyValueStorageKeys {
    /// quickconnect id -> synology server site
    case SYNOLOGY_SERVER_URL(String)

    case DISK_STATION_API_INFO
    case DISK_STATION_API_INFO_UPDATE_TIME

    case DISK_STATION_AUDIO_STATION_INFO
    case DISK_STATION_AUDIO_STATION_INFO_UPDATE_TIME

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
        }
    }
}
