//
//  KeyValueStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 键值存储协议（解耦 UserDefaults）
/// Key-Value Storage Protocol (Decouple UserDefaults)
public protocol KeyValueStorage: Sendable {
    
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func bool(forKey defaultName: String) -> Bool
    func object(forKey defaultName: String) -> Any?
    func data(forKey defaultName: String) -> Data?
    
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    
    // 注意：Actor 环境下不再需要显示调用 synchronize，
    // 具体实现应自己处理持久化策略。
}

// MARK: - UserDefaults Implementation

/// 基于 UserDefaults 的存储实现
public final class UserDefaultsStorage: KeyValueStorage, @unchecked Sendable {
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
}
