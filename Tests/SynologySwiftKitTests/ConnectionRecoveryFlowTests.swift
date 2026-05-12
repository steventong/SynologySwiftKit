import XCTest
@testable import SynologySwiftKit

final class ConnectionRecoveryFlowTests: XCTestCase {
    func testRecoverConnectionRestoresPersistedQuickConnectEndpointAndSchedulesOptimization() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)

        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: true),
            keyChainStorage: keychain
        )

        let decision = await recovery.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertEqual(decision.followUp, .optimizeQuickConnectEndpoint)
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://cached.local")
    }

    func testRecoverConnectionWithUnreachableQuickConnectEndpointRequiresRelogin() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://cached.local", typeString: ConnectionType.lan.rawValue)

        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: keychain
        )

        let decision = await recovery.recoverConnection()

        XCTAssertEqual(decision.status, .requiresRelogin)
        XCTAssertNil(decision.followUp)
    }

    func testRecoverConnectionWithUnreachableCustomDomainDisconnects() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "nas.example.com", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://nas.example.com", typeString: ConnectionType.custom_domain.rawValue)

        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: keychain
        )

        let decision = await recovery.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
        XCTAssertNil(decision.followUp)
    }

    func testRecoverConnectionWithoutCredentialsDisconnects() async {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)

        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: TestPingPong()),
            pingpong: TestPingPong(singleURLReachable: false),
            keyChainStorage: keychain
        )

        let decision = await recovery.recoverConnection()

        XCTAssertEqual(decision.status, .disconnected)
        XCTAssertNil(decision.followUp)
    }

    func testOptimizeQuickConnectEndpointPersistsRefreshedConnection() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = TestPingPong(firstResult: refreshed, singleURLReachable: true)
        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            keyChainStorage: keychain
        )

        let connection = await recovery.optimizeQuickConnectEndpoint()

        XCTAssertEqual(connection?.type, .lan)
        XCTAssertEqual(connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
    }
}

private func makeQuickConnectServerInfo(ip: String, port: Int) throws -> QuickConnectClient.ServerInfo {
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
