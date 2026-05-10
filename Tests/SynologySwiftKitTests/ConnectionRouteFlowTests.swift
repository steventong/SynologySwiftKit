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
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: nil, isPortalPort: false, sid: "sid"))),
            keyChainStorage: keychain
        )

        let candidates = try await manager.listCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(candidates.first?.type, .lan)
        XCTAssertEqual(candidates.first?.isCurrent, true)
        XCTAssertEqual(candidates.first?.isReachable, true)
    }

    func testSwitchConnectionPersistsSelectedEndpointAndRefreshesSession() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let manager = ConnectionRouteManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
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
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(apiClient.session?.did, "new-did")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "new-did")
    }

    func testSwitchConnectionRollsBackConnectionAndSessionWhenSilentLoginFails() async {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")

        let manager = ConnectionRouteManager(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            apiInfoApi: TestApiInfoProvider(onRefresh: {
                throw SynologyError.network(message: "refresh failed")
            }),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            keyChainStorage: keychain
        )

        do {
            _ = try await manager.switchConnection(
                to: SynologyConnection(type: .relay, url: "https://relay.quickconnect.to:443")
            )
            XCTFail("Expected switch failure")
        } catch let SynologyError.network(message) {
            XCTAssertEqual(message, "refresh failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
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
