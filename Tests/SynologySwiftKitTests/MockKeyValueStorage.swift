//
//  MockKeyValueStorage.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation
@testable import SynologySwiftKit

/// 内存实现的 Mock 存储（用于测试）
public final class MockKeyValueStorage: KeyValueStorage, @unchecked Sendable {
    // 使用锁保护字典，模拟线程安全的存储
    private let lock = NSLock()
    private var storage: [String: StoredValue] = [:]

    public init() {}

    public func string(forKey defaultName: String) -> String? {
        lock.withLock {
            guard case let .string(value) = storage[defaultName] else { return nil }
            return value
        }
    }

    public func integer(forKey defaultName: String) -> Int {
        lock.withLock {
            guard case let .integer(value) = storage[defaultName] else { return 0 }
            return value
        }
    }

    public func bool(forKey defaultName: String) -> Bool {
        lock.withLock {
            guard case let .bool(value) = storage[defaultName] else { return false }
            return value
        }
    }

    public func date(forKey defaultName: String) -> Date? {
        lock.withLock {
            guard case let .date(value) = storage[defaultName] else { return nil }
            return value
        }
    }
    
    public func data(forKey defaultName: String) -> Data? {
        lock.withLock {
            guard case let .data(value) = storage[defaultName] else { return nil }
            return value
        }
    }

    public func codable<T: Decodable>(forKey defaultName: String) -> T? {
        guard let data = self.data(forKey: defaultName) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func setString(_ value: String?, forKey defaultName: String) {
        set(value.map(StoredValue.string), forKey: defaultName)
    }

    public func setInteger(_ value: Int, forKey defaultName: String) {
        set(.integer(value), forKey: defaultName)
    }

    public func setBool(_ value: Bool, forKey defaultName: String) {
        set(.bool(value), forKey: defaultName)
    }

    public func setDate(_ value: Date?, forKey defaultName: String) {
        set(value.map(StoredValue.date), forKey: defaultName)
    }

    public func setData(_ value: Data?, forKey defaultName: String) {
        set(value.map(StoredValue.data), forKey: defaultName)
    }

    public func setCodable<T: Encodable>(_ value: T?, forKey defaultName: String) {
        guard let value else {
            removeObject(forKey: defaultName)
            return
        }

        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        setData(data, forKey: defaultName)
    }

    public func removeObject(forKey defaultName: String) {
        lock.withLock { _ = storage.removeValue(forKey: defaultName) }
    }
    
    // 辅助方法：清空所有数据
    public func clearAll() {
        lock.withLock { storage.removeAll() }
    }

    private func set(_ value: StoredValue?, forKey defaultName: String) {
        lock.withLock {
            if let value {
                storage[defaultName] = value
            } else {
                storage.removeValue(forKey: defaultName)
            }
        }
    }
}

private enum StoredValue: Sendable {
    case string(String)
    case integer(Int)
    case bool(Bool)
    case date(Date)
    case data(Data)
}
