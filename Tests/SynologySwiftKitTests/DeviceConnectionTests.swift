//
//  DeviceConnectionTests.swift
//  SynologySwiftKitTests
//
//  Created by Steven on 2024/6/1.
//

import XCTest
@testable import SynologySwiftKit

final class DeviceConnectionTests: XCTestCase {

    var storage: MockKeyValueStorage!
    var deviceConnection: DeviceConnection!

    override func setUp() async throws {
        // 使用 Mock 存储，无需清理 UserDefaults
        storage = MockKeyValueStorage()
        deviceConnection = DeviceConnection(storage: storage)
    }

    override func tearDown() async throws {
        storage = nil
        deviceConnection = nil
    }

    func testUpdateCurrentConnectionUrl() async {
        let type = ConnectionType.quickConnect
        let url = "http://quickconnect.to/test"

        await deviceConnection.updateCurrentConnectionUrl(type: type, url: url)

        // 验证内存状态
        let current = await deviceConnection.getCurrentConnectionUrl()
        XCTAssertEqual(current?.type, type)
        XCTAssertEqual(current?.url, url)

        // 验证持久化存储
        let savedUrl = storage.string(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
        XCTAssertEqual(savedUrl, url)
    }

    func testConcurrentAccess() async {
        // 模拟并发读写，验证 actor 的线程安全性
        let type = ConnectionType.custom_domain
        let url = "https://example.com"

        await withTaskGroup(of: Void.self) { group in
            // 100 个并发写
            for i in 0..<100 {
                group.addTask {
                    await self.deviceConnection.updateCurrentConnectionUrl(type: type, url: "\(url)/\(i)")
                }
            }
            // 100 个并发读
            for _ in 0..<100 {
                group.addTask {
                    _ = await self.deviceConnection.getCurrentConnectionUrl()
                }
            }
        }

        // 最终状态应该是一致的（虽然具体是哪一次写入不确定，但不能 crash 或状态错乱）
        let final = await deviceConnection.getCurrentConnectionUrl()
        XCTAssertNotNil(final)
        XCTAssertTrue(final?.url.hasPrefix(url) ?? false)
    }
    
    func testLoginSessionLifecycle() async {
        // 初始状态为空
        let emptySession = await deviceConnection.getLoginSession()
        XCTAssertNil(emptySession)
        
        // 模拟登录
        await deviceConnection.updateLoginSession(username: "admin", sid: "sid_123", did: "did_456")
        
        let session = await deviceConnection.getLoginSession()
        XCTAssertEqual(session?.sid, "sid_123")
        XCTAssertEqual(session?.did, "did_456")
        
        // 模拟退出
        await deviceConnection.removeLoginSession()
        
        let removedSession = await deviceConnection.getLoginSession()
        XCTAssertNil(removedSession)
    }
}
