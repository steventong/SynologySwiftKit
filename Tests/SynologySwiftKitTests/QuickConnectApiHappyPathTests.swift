import XCTest
@testable import SynologySwiftKit

final class QuickConnectClientHappyPathTests: XCTestCase {
    func testGetDeviceConnectionFollowsRedirectAndReturnsBestReachableURL() async throws {
        let transport = MockHTTPTransport()
        let apiClient = ApiClient(httpTransport: transport)
        let storage = MockKeyValueStorage()
        let pingpong = TestPingPong(firstResult: SynologyConnection(type: .lan, url: "https://192.168.1.2:5001"))
        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: pingpong,
            timeout: 2,
            keyValueStorage: storage
        )

        transport.handler = { request, _, _ in
            let url = try XCTUnwrap(request.url)
            if url.host == SynologySwiftKitConstant.GLOBAL_SYNOLOGY_CONNECT_SERVER {
                return (
                    try makeJSONData([
                    "command": "get_server_info",
                    "version": 1,
                    "errno": 4,
                    "sites": ["global2.quickconnect.to"],
                ]),
                    makeHTTPURLResponse(url: url)
                )
            }

            return (
                try makeJSONData([
                "command": "get_server_info",
                "version": 1,
                "errno": 0,
                "server": [
                    "external": ["ip": "8.8.8.8"],
                    "interface": [["ip": "192.168.1.2"]],
                    "ddns": "demo.synology.me",
                ],
                "service": [
                    "port": 5001,
                    "ext_port": 5001,
                    "relay_dn": "relay.quickconnect.to",
                    "relay_port": 443,
                ],
            ]),
                makeHTTPURLResponse(url: url)
            )
        }

        let connection = try await quickConnectApi.getDeviceConnection(quickConnectId: "demoqc", usesHTTPS: true)

        XCTAssertEqual(connection.type, .lan)
        XCTAssertEqual(connection.url, "https://192.168.1.2:5001")
        XCTAssertEqual(
            storage.string(forKey: KeyValueStorageKeys.SYNOLOGY_SERVER_URL("demoqc").keyName),
            "global2.quickconnect.to"
        )
    }
}
