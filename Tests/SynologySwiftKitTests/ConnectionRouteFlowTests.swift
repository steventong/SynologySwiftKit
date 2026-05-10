import XCTest
@testable import SynologySwiftKit

final class ConnectionRouteFlowTests: XCTestCase {
    func testListCandidatesIncludesCurrentFlagAndReachability() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeConnectionRouteServerInfo(ip: "192.168.1.10", port: 5001)
        }

        let manager = ConnectionRouteManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        let candidates = try await manager.listCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(candidates.first?.type, .lan)
        XCTAssertEqual(candidates.first?.isCurrent, true)
        XCTAssertEqual(candidates.first?.isReachable, true)
    }

    func testSwitchConnectionPersistsSelectedEndpoint() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        let manager = ConnectionRouteManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        let updated = try await manager.switchConnection(
            to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
        )

        XCTAssertEqual(updated.type, .relay)
        XCTAssertEqual(updated.url, "https://relay.quickconnect.to:443")
        XCTAssertEqual(apiClient.connection?.type, .relay)
        XCTAssertEqual(apiClient.connection?.url, "https://relay.quickconnect.to:443")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.relay.rawValue)
    }
}

private func makeConnectionRouteServerInfo(ip: String, port: Int) throws -> QuickConnectClient.ServerInfo {
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
