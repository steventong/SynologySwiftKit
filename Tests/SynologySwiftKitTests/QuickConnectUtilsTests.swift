import XCTest
@testable import SynologySwiftKit

final class QuickConnectUtilsTests: XCTestCase {
    func testRecognizesQuickConnectIdentifiers() {
        XCTAssertTrue(QuickConnectUtils.isQuickConnectId(server: "DSMusic"))
        XCTAssertTrue(QuickConnectUtils.isQuickConnectId(server: "  qc-123456  "))
    }

    func testRejectsCustomHostsPortsSchemesAndEmptyValues() {
        XCTAssertFalse(QuickConnectUtils.isQuickConnectId(server: "nas.example.com"))
        XCTAssertFalse(QuickConnectUtils.isQuickConnectId(server: "nas:5001"))
        XCTAssertFalse(QuickConnectUtils.isQuickConnectId(server: "https://nas"))
        XCTAssertFalse(QuickConnectUtils.isQuickConnectId(server: "2001:db8::1"))
        XCTAssertFalse(QuickConnectUtils.isQuickConnectId(server: "  "))
    }
}
