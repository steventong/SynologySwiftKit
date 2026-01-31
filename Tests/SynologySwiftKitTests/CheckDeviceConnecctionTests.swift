//

//
//
//  Created by Steven on 2024/5/4.
//

@testable import SynologySwiftKit
import XCTest

final class CheckDeviceConnecctionTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// 创建测试用的 CheckDeviceConnection 实例
    /// Create a test CheckDeviceConnection instance
    private func makeCheckDeviceConnection() -> CheckDeviceConnection {
        let client = SynologyClient()
        return client.checkDeviceConnection
    }
    
    // MARK: - AsyncStream Tests
    
    /// 测试使用 AsyncStream 版本的 checkConnectionStatus
    /// Test checkConnectionStatus with AsyncStream version
    @MainActor
    func testCheckDeviceStatusWithAsyncStream() async throws {
        let checker = makeCheckDeviceConnection()
        
        for await progress in checker.checkConnectionStatus(fetchNewServerByQuickConnectId: true) {
            switch progress {
            case .checkingExistingConnection(let url):
                Logger.info("testCheckDeviceStatus, checking existing connection: \(url)")
            case .existingConnectionAvailable(let type, let url):
                Logger.info("testCheckDeviceStatus, existing connection available: \(type) \(url)")
            case .fetchingQuickConnect(let qcId):
                Logger.info("testCheckDeviceStatus, fetching QuickConnect: \(qcId)")
            case .quickConnectFetched(let type, let url):
                Logger.info("testCheckDeviceStatus, QuickConnect fetched: \(type) \(url)")
            case .queryingApiInfo:
                Logger.info("testCheckDeviceStatus, querying API info")
            case .queryingAudioStation:
                Logger.info("testCheckDeviceStatus, querying AudioStation")
            case .success(let type, let url, let info):
                Logger.info("testCheckDeviceStatus, success: \(type) \(url), version: \(info.version_string ?? "unknown")")
            case .failed(let reason):
                Logger.error("testCheckDeviceStatus, failed: \(reason)")
            case .loginRequired(let reason):
                Logger.info("testCheckDeviceStatus, login required: \(reason)")
            }
        }
    }
    
    // MARK: - Async/Await Tests
    
    /// 测试 queryDsmInfo 方法
    /// Test queryDsmInfo method
    @MainActor
    func testQueryDsmInfo() async throws {
        let checker = makeCheckDeviceConnection()
        
        do {
            let dsmInfo = try await checker.queryDsmInfo()
            Logger.info("testQueryDsmInfo, dsmInfo: \(dsmInfo)")
        } catch {
            Logger.error("testQueryDsmInfo, error: \(error)")
        }
    }
    
    /// 测试 queryAudioStationInfo 方法
    /// Test queryAudioStationInfo method
    @MainActor
    func testQueryAudioStationInfo() async throws {
        let checker = makeCheckDeviceConnection()
        
        do {
            let audioStationInfo = try await checker.queryAudioStationInfo()
            Logger.info("testQueryAudioStationInfo, audioStationInfo: \(audioStationInfo)")
        } catch {
            Logger.error("testQueryAudioStationInfo, error: \(error)")
        }
    }
}
