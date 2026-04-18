import XCTest
@testable import SynologySwiftKit

final class UserDefaultsStorageTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaultsStorage!

    override func setUp() {
        super.setUp()
        suiteName = "SynologySwiftKitTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        storage = UserDefaultsStorage(userDefaults: userDefaults)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        storage = nil
        suiteName = nil
        super.tearDown()
    }

    func testRoundTripsCodableValues() {
        let value = DemoSettings(name: "demo", retryCount: 3)

        storage.set(value, forKey: "settings")
        let decoded: DemoSettings? = storage.codable(forKey: "settings")

        XCTAssertEqual(decoded, value)
    }

    func testRemovingCodableValueClearsStoredData() {
        storage.set(DemoSettings(name: "demo", retryCount: 3), forKey: "settings")
        storage.set(Optional<DemoSettings>.none, forKey: "settings")

        let decoded: DemoSettings? = storage.codable(forKey: "settings")
        XCTAssertNil(decoded)
    }
}

private struct DemoSettings: Codable, Equatable {
    let name: String
    let retryCount: Int
}
