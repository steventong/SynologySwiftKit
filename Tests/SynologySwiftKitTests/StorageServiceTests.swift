import XCTest
@testable import SynologySwiftKit

final class StorageServiceTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var keychain: KeyChainStorage!
    private var storage: StorageService!

    override func setUp() {
        super.setUp()
        suiteName = "StorageServiceTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        keychain = makeKeyChainStorage(service: suiteName)
        storage = StorageService(
            keyValueStorage: UserDefaultsStorage(userDefaults: userDefaults),
            keyChainStorage: keychain
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        storage.removeCredentials()
        for account in storage.getLoginAccountHistory() {
            storage.removeLoginAccountFromHistory(id: account.id)
        }
        storage.removeSessionInfo()
        storage.removeConnectionInfo()
        userDefaults = nil
        keychain = nil
        storage = nil
        suiteName = nil
        super.tearDown()
    }

    func testStoresRegularCodableValuesInUserDefaultsByDefault() {
        let settings = DemoSettings(name: "demo", retryCount: 3)

        storage.setValue(settings, forKey: "settings")

        let decoded: DemoSettings? = storage.value(forKey: "settings")
        XCTAssertEqual(decoded, settings)
        XCTAssertNotNil(userDefaults.data(forKey: "settings"))
        let keychainValue: DemoSettings? = keychain.codable(forKey: "settings")
        XCTAssertNil(keychainValue)
    }

    func testStoresSensitiveValuesInKeychainByDefault() {
        let token = DemoSecretToken(value: "secret-token")

        storage.setValue(token, forKey: "token")

        let decoded: DemoSecretToken? = storage.value(forKey: "token")
        XCTAssertEqual(decoded, token)
        XCTAssertNil(userDefaults.data(forKey: "token"))
        let keychainValue: DemoSecretToken? = keychain.codable(forKey: "token")
        XCTAssertEqual(keychainValue, token)
    }

    func testSupportsPrimitiveAndCollectionTypesThroughUnifiedApi() {
        storage.setValue("hello", forKey: "string")
        storage.setValue(42, forKey: "integer")
        storage.setValue(true, forKey: "bool")
        storage.setValue(["a", "b", "c"], forKey: "array")

        let stringValue: String? = storage.value(forKey: "string")
        let integerValue: Int? = storage.value(forKey: "integer")
        let boolValue: Bool? = storage.value(forKey: "bool")
        let arrayValue: [String]? = storage.value(forKey: "array")

        XCTAssertEqual(stringValue, "hello")
        XCTAssertEqual(integerValue, 42)
        XCTAssertEqual(boolValue, true)
        XCTAssertEqual(arrayValue, ["a", "b", "c"])
    }

    func testSensitiveStorageApiUsesUnifiedService() {
        storage.saveCredentials(server: "demo.local", username: "user", password: "pwd", usesHTTPS: true)
        storage.saveSessionInfo(sid: "sid-123", did: "did-456")
        storage.saveConnectionInfo(url: "https://demo.local:5001", typeString: "lan")
        storage.saveDeviceInfo("did-456", "phone")

        XCTAssertEqual(storage.getCredentials(), SynologyCredentials(server: "demo.local", username: "user", password: "pwd", usesHTTPS: true))
        XCTAssertEqual(storage.getSessionInfo()?.sid, "sid-123")
        XCTAssertEqual(storage.getSessionInfo()?.did, "did-456")
        XCTAssertEqual(storage.getConnectionInfo()?.url, "https://demo.local:5001")
        XCTAssertEqual(storage.getConnectionInfo()?.typeString, "lan")
        XCTAssertEqual(storage.getDeviceInfo()?.0, "did-456")
        XCTAssertEqual(storage.getDeviceInfo()?.1, "phone")
    }

    func testSensitiveStoragePersistsInSingleUnifiedKeychainAccount() {
        keychain.saveCredentials(server: "demo.local", username: "user", password: "pwd", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "sid-123", did: "did-456")
        keychain.saveConnectionInfo(url: "https://demo.local:5001", typeString: "lan")
        keychain.saveDeviceInfo("did-456", "phone")

        let payload: UnifiedKeychainPayload? = keychain.codable(forKey: "synology_secure_store")
        XCTAssertEqual(payload?.credentials?.username, "user")
        XCTAssertEqual(payload?.sessionInfo?.sid, "sid-123")
        XCTAssertEqual(payload?.connectionInfo?.url, "https://demo.local:5001")
        XCTAssertEqual(payload?.deviceInfo?.did, "did-456")
        XCTAssertEqual(payload?.loginAccountHistory?.first?.server, "demo.local")

        let legacyCredentials: SynologyCredentials? = keychain.codable(forKey: "synology_credentials")
        let legacySession: SynologySessionInfo? = keychain.codable(forKey: "synology_session_info")
        XCTAssertNil(legacyCredentials)
        XCTAssertNil(legacySession)
    }

    func testLoginAccountHistoryDeduplicatesMovesNewestFirstAndDeletes() {
        storage.saveCredentials(server: "nas-a.local", username: "alice", password: "old-password", usesHTTPS: true)
        storage.saveCredentials(server: "nas-b.local", username: "bob", password: "bob-password", usesHTTPS: true)
        storage.saveCredentials(server: "NAS-A.LOCAL", username: "alice", password: "new-password", usesHTTPS: true)

        var history = storage.getLoginAccountHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].server, "NAS-A.LOCAL")
        XCTAssertEqual(history[0].username, "alice")
        XCTAssertEqual(history[0].password, "new-password")
        XCTAssertEqual(history[1].server, "nas-b.local")

        storage.removeLoginAccountFromHistory(id: history[0].id)

        history = storage.getLoginAccountHistory()
        XCTAssertEqual(history.map(\.username), ["bob"])
    }

}

private struct DemoSettings: Codable, Equatable, Sendable {
    let name: String
    let retryCount: Int
}

private struct DemoSecretToken: Codable, Equatable, Sendable, SensitiveStorageValue {
    let value: String
}

private struct UnifiedKeychainPayload: Codable {
    let credentials: SynologyCredentials?
    let loginAccountHistory: [SynologyLoginAccountHistoryItem]?
    let sessionInfo: SynologySessionInfo?
    let connectionInfo: SynologyConnectionInfo?
    let deviceInfo: SynologyDeviceInfo?
}
