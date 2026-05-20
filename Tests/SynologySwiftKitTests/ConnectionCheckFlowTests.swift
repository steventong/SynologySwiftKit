import XCTest
@testable import SynologySwiftKit

final class ConnectionCheckFlowTests: XCTestCase {
    func testCheckReturnsCachedCurrentConnection() async {
        let apiClient = MockApiClient()
        apiClient.connection = (.custom_domain, "https://nas.local")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.local", username: "tester", password: "secret", usesHTTPS: true)

        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case .checking = events[0] else {
            return XCTFail("Expected checking event first")
        }
        guard case let .success(connection, usedCachedConnection) = events[1] else {
            return XCTFail("Expected cached success event")
        }
        XCTAssertEqual(connection.type, .custom_domain)
        XCTAssertEqual(connection.url, "https://nas.local")
        XCTAssertTrue(usedCachedConnection)
    }

    func testCheckWithoutCredentialsEmitsFailure() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(),
            keyChainStorage: keychain
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 1)
        guard case let .failed(message) = events[0] else {
            return XCTFail("Expected a terminal failure event")
        }
        XCTAssertTrue(message.contains("no saved credentials"))
    }

    func testCheckForCustomDomainResolvesDirectly() async {
        let apiClient = MockApiClient()
        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: KeyChainStorage(service: UUID().uuidString)
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check(server: "nas.local", usesHTTPS: true) {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case let .success(connection, usedCachedConnection) = events[1] else {
            return XCTFail("Expected refreshed success")
        }
        XCTAssertEqual(connection.type, .custom_domain)
        XCTAssertEqual(connection.url, "nas.local")
        XCTAssertFalse(usedCachedConnection)
    }

    func testCheckFallsBackWhenCachedConnectionIsUnreachable() async {
        let apiClient = MockApiClient()
        apiClient.connection = (.custom_domain, "https://stale.local")

        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: URLReachabilityPingPong(reachability: [
                "https://stale.local": false,
                "nas.local": true,
            ]),
            keyChainStorage: KeyChainStorage(service: UUID().uuidString)
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check(server: "nas.local", usesHTTPS: true) {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case let .success(connection, usedCachedConnection) = events[1] else {
            return XCTFail("Expected fallback success")
        }
        XCTAssertEqual(connection.url, "nas.local")
        XCTAssertFalse(usedCachedConnection)
    }

    func testCheckFailsWhenQuickConnectResolutionFails() async {
        let apiClient = MockApiClient()
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            throw SynologyError.network(message: "qc failed")
        }

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "QC123456", username: "tester", password: "secret", usesHTTPS: true)

        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: keychain
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case .checking = events[0] else {
            return XCTFail("Expected checking event first")
        }
        guard case let .failed(message) = events[1] else {
            return XCTFail("Expected failure event")
        }
        XCTAssertTrue(message.contains("qc failed"))
    }

    func testCheckFailsWhenResolvedEndpointIsUnreachable() async {
        let apiClient = MockApiClient()
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeConnectionCheckServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "QC123456", username: "tester", password: "secret", usesHTTPS: true)

        let checker = ConnectionChecker(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: keychain
        )

        var events: [ConnectionCheckProgress] = []
        for await progress in checker.check() {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 2)
        guard case let .failed(message) = events[1] else {
            return XCTFail("Expected failure event")
        }
        XCTAssertEqual(
            message,
            SynologyError.network(message: "Failed to establish QuickConnect connection").localizedDescription
        )
    }
}

private struct URLReachabilityPingPong: PingPongProviding {
    let reachability: [String: Bool]

    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        nil
    }

    func pingpong(url: String) async -> Bool {
        reachability[url] ?? false
    }
}

private func makeConnectionCheckServerInfo(ip: String, port: Int) throws -> QuickConnectClient.ServerInfo {
    let json: [String: Any] = [
        "command": "get_server_info",
        "version": 1,
        "errno": 0,
        "server": [
            "interface": [
                [
                    "ip": ip,
                    "name": "eth0",
                    "mask": "255.255.255.0",
                ],
            ],
        ],
        "service": [
            "id": "dsm_https",
            "port": port,
        ],
    ]

    let data = try makeJSONData(json)
    return try JSONDecoder().decode(QuickConnectClient.ServerInfo.self, from: data)
}
