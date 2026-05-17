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
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            keyChainStorage: keychain
        )

        let connection = await recovery.optimizeQuickConnectEndpoint()

        XCTAssertEqual(connection?.type, .lan)
        XCTAssertEqual(connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(apiClient.session?.did, "new-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "new-did")
    }

    func testRecoverConnectionPingsCurrentEndpointThenOptimizesAndPersistsAfterLogin() async throws {
        let apiClient = MockApiClient()
        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = RecordingPingPong(firstResult: refreshed, singleURLReachable: true)
        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .success(AuthResult(did: "new-did", isPortalPort: false, sid: "new-sid"))),
            keyChainStorage: keychain
        )

        let decision = await recovery.recoverConnection()

        XCTAssertEqual(decision.status, .connected)
        XCTAssertNil(decision.followUp)
        XCTAssertEqual(pingpong.singleURLPings.first, "https://192.168.1.10:5001")
        XCTAssertTrue(pingpong.didRunBestConnectionSelection)
        XCTAssertEqual(apiClient.session?.sid, "new-sid")
        XCTAssertEqual(apiClient.session?.did, "new-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.20:5001")
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "new-sid")
    }

    func testOptimizeQuickConnectEndpointDoesNotPersistRefreshedConnectionWhenLoginFails() async throws {
        let apiClient = MockApiClient()
        apiClient.updateConnection(type: .lan, url: "https://192.168.1.10:5001")
        apiClient.updateSession(sid: "old-sid", did: "old-did")

        let keychain = KeyChainStorage(service: UUID().uuidString)
        keychain.saveCredentials(server: "qc-123456", username: "tester", password: "secret", usesHTTPS: true)
        keychain.saveConnectionInfo(url: "https://192.168.1.10:5001", typeString: ConnectionType.lan.rawValue)
        keychain.saveSessionInfo(sid: "old-sid", did: "old-did")
        apiClient.rawRequestHandler = { _, _, _, _, _ in
            try makeQuickConnectServerInfo(ip: "192.168.1.20", port: 5001)
        }

        let refreshed = SynologyConnection(type: .lan, url: "https://192.168.1.20:5001")
        let pingpong = TestPingPong(firstResult: refreshed, singleURLReachable: true)
        let recovery = ConnectionRecovery(
            apiClient: apiClient,
            quickConnectApi: QuickConnectClient(apiClient: apiClient, pingpong: pingpong),
            pingpong: pingpong,
            apiInfoApi: TestApiInfoProvider(),
            authApi: TestAuthProvider(result: .failure(SynologyError.auth(code: 400, message: "login failed"))),
            keyChainStorage: keychain
        )

        let connection = await recovery.optimizeQuickConnectEndpoint()

        XCTAssertNil(connection)
        XCTAssertEqual(apiClient.connection?.type, .lan)
        XCTAssertEqual(apiClient.connection?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(apiClient.session?.sid, "old-sid")
        XCTAssertEqual(apiClient.session?.did, "old-did")
        XCTAssertEqual(keychain.getConnectionInfo()?.url, "https://192.168.1.10:5001")
        XCTAssertEqual(keychain.getConnectionInfo()?.typeString, ConnectionType.lan.rawValue)
        XCTAssertEqual(keychain.getSessionInfo()?.sid, "old-sid")
        XCTAssertEqual(keychain.getSessionInfo()?.did, "old-did")
    }
}

private final class RecordingPingPong: PingPongProviding, @unchecked Sendable {
    let firstResult: SynologyConnection?
    let singleURLReachable: Bool
    private let queue = DispatchQueue(label: "RecordingPingPong.state")
    private var storedSingleURLPings: [String] = []
    private var storedDidRunBestConnectionSelection = false

    var singleURLPings: [String] {
        queue.sync { storedSingleURLPings }
    }

    var didRunBestConnectionSelection: Bool {
        queue.sync { storedDidRunBestConnectionSelection }
    }

    init(firstResult: SynologyConnection?, singleURLReachable: Bool) {
        self.firstResult = firstResult
        self.singleURLReachable = singleURLReachable
    }

    func pingpong(connections: [ConnectionType: [String]]) async -> [ConnectionType: String] {
        [:]
    }

    func pingpongFirst(connections: [ConnectionType: [String]]) async -> (type: ConnectionType, url: String)? {
        queue.sync {
            storedDidRunBestConnectionSelection = true
        }

        guard let firstResult else {
            return nil
        }
        return (firstResult.type, firstResult.url)
    }

    func pingpong(url: String) async -> Bool {
        queue.sync {
            storedSingleURLPings.append(url)
        }
        return singleURLReachable
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
