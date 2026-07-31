import XCTest
@testable import SynologySwiftKit

final class LoginServerAddressResolverTests: XCTestCase {
    func testBareHostPrefersHTTPSDefaultPortThenHTTPDefaultPort() throws {
        XCTAssertEqual(
            try LoginServerAddressResolver.automaticAttempts(for: "nas.local"),
            [
                LoginConnectionAttempt(server: "https://nas.local:5001", usesHTTPS: true),
                LoginConnectionAttempt(server: "http://nas.local:5000", usesHTTPS: false),
            ]
        )
    }

    func testBareHostWithPortReusesPortForBothProtocols() throws {
        XCTAssertEqual(
            try LoginServerAddressResolver.automaticAttempts(for: "nas.local:8443"),
            [
                LoginConnectionAttempt(server: "https://nas.local:8443", usesHTTPS: true),
                LoginConnectionAttempt(server: "http://nas.local:8443", usesHTTPS: false),
            ]
        )
    }

    func testExplicitSchemeIsAuthoritative() throws {
        XCTAssertEqual(
            try LoginServerAddressResolver.automaticAttempts(for: "http://nas.local:8080"),
            [LoginConnectionAttempt(server: "http://nas.local:8080", usesHTTPS: false)]
        )
        XCTAssertEqual(
            try LoginServerAddressResolver.automaticAttempts(for: "https://nas.local"),
            [LoginConnectionAttempt(server: "https://nas.local", usesHTTPS: true)]
        )
    }

    func testQuickConnectPrefersAudioHTTPSThenAudioHTTP() throws {
        XCTAssertEqual(
            try LoginServerAddressResolver.automaticAttempts(for: "QC123456"),
            [
                LoginConnectionAttempt(server: "QC123456", usesHTTPS: true),
                LoginConnectionAttempt(server: "QC123456", usesHTTPS: false),
            ]
        )
    }
}
