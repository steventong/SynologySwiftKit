//
//  MockKeyValueStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

/// 内存实现的 Mock 存储（用于测试）
public final class MockKeyValueStorage: KeyValueStorage, @unchecked Sendable {
    // 使用锁保护字典，模拟线程安全的存储
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    public init() {}

    public func string(forKey defaultName: String) -> String? {
        lock.withLock { storage[defaultName] as? String }
    }

    public func integer(forKey defaultName: String) -> Int {
        lock.withLock { storage[defaultName] as? Int ?? 0 }
    }

    public func bool(forKey defaultName: String) -> Bool {
        lock.withLock { storage[defaultName] as? Bool ?? false }
    }

    public func object(forKey defaultName: String) -> Any? {
        lock.withLock { storage[defaultName] }
    }
    
    public func data(forKey defaultName: String) -> Data? {
        lock.withLock { storage[defaultName] as? Data }
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock {
            if let value = value {
                storage[defaultName] = value
            } else {
                storage.removeValue(forKey: defaultName)
            }
        }
    }

    public func removeObject(forKey defaultName: String) {
        lock.withLock { _ = storage.removeValue(forKey: defaultName) }
    }
    
    // 辅助方法：清空所有数据
    public func clearAll() {
        lock.withLock { storage.removeAll() }
    }
}
