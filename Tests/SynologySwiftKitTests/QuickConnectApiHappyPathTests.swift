import XCTest
@testable import SynologySwiftKit

final class QuickConnectClientHappyPathTests: XCTestCase {
    func testGetDeviceConnectionFollowsRedirectAndReturnsBestReachableURL() async throws {
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let storage = MockKeyValueStorage()
        let pingpong = TestPingPong(firstResult: SynologyConnection(type: .lan, url: "https://192.168.1.2:5001"))
        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: pingpong,
            timeout: 2,
            keyValueStorage: storage
        )

        transport.handler = { request, _ in
            let url = try XCTUnwrap(request.url)
            let body = try XCTUnwrap(requestBodyData(request))
            let parameters = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(parameters["id"] as? String, "audio_https")
            XCTAssertNil(parameters["stop_when_success"])
            XCTAssertNil(parameters["stop_when_error"])
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

    func testListDeviceConnectionsBuildsPreferredCandidatesFromServerInfo() async throws {
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: TestPingPong(),
            timeout: 2,
            keyValueStorage: MockKeyValueStorage()
        )

        transport.handler = { request, _ in
            (
                try makeJSONData([
                    "command": "get_server_info",
                    "version": 1,
                    "errno": 0,
                    "server": [
                        "redirect_prefix": "music",
                        "pingpong_path": "webman/pingpong.cgi?action=cors&quickconnect=true",
                        "external": [
                            "ip": "210.187.192.92",
                            "ipv6": "2001:e68:541b:b473:211:32ff:fed5:a5ab",
                        ],
                        "ddns": "steventong.synology.me",
                        "interface": [[
                            "ip": "192.168.0.5",
                            "ipv6": [
                                [
                                    "scope": "global",
                                    "addr_type": 0,
                                    "prefix_length": 64,
                                    "address": "2001:e68:541b:b473:211:32ff:fed5:a5ab",
                                ],
                                [
                                    "scope": "link",
                                    "addr_type": 32,
                                    "prefix_length": 64,
                                    "address": "fe80::211:32ff:fed5:a5ab",
                                ],
                            ],
                        ]],
                    ],
                    "service": [
                        "port": 5001,
                        "ext_port": 15001,
                        "relay_dn": "synr-sg4.STEVENTONG.direct.quickconnect.to",
                        "relay_dualstack": "synr-sg4.STEVENTONG.direct.quickconnect.to",
                        "relay_ipv6": "2001:df1:800:c001:1::",
                        "relay_port": 39446,
                        "https_ip": "209.58.169.44",
                        "https_port": 443,
                    ],
                    "smartdns": [
                        "host": "STEVENTONG.direct.quickconnect.to",
                        "external": "syn4-l5bb577of66bb7naliv6zum7de-210-187-192-92.steventong.direct.quickconnect.to",
                        "externalv6": "syn6-4674d65jyhgw5qbkfcwolaqqlaeaaq42cudo2hgaqrgl775vnfvm.steventong.direct.quickconnect.to",
                        "lan": ["192-168-0-5.STEVENTONG.direct.quickconnect.to"],
                        "lanv6": [
                            "syn6-4674d65jyhgw5qbkfcwolaqqlaeaaq42cudo2hgaqrgl775vnfvm.steventong.direct.quickconnect.to",
                        ],
                    ],
                ]),
                makeHTTPURLResponse(url: try XCTUnwrap(request.url))
            )
        }

        let connections = try await quickConnectApi.listDeviceConnections(quickConnectId: "demoqc", usesHTTPS: true)

        XCTAssertEqual(connections.map(\.type), [
            .lan, .lan,
            .lanv6, .lanv6,
            .ddns, .ddns, .ddns, .ddns,
            .wan, .wan, .wan, .wan, .wan,
            .wanv6, .wanv6, .wanv6, .wanv6,
            .relay, .relay,
        ])
        XCTAssertEqual(connections.map(\.url), [
            "https://192.168.0.5:5001/music",
            "https://192-168-0-5.STEVENTONG.direct.quickconnect.to:5001/music",
            "https://[2001:e68:541b:b473:211:32ff:fed5:a5ab]:5001/music",
            "https://syn6-4674d65jyhgw5qbkfcwolaqqlaeaaq42cudo2hgaqrgl775vnfvm.steventong.direct.quickconnect.to:5001/music",
            "https://steventong.synology.me:5001/music",
            "https://steventong.synology.me:15001/music",
            "https://STEVENTONG.direct.quickconnect.to:5001/music",
            "https://STEVENTONG.direct.quickconnect.to:15001/music",
            "https://210.187.192.92:15001/music",
            "https://210.187.192.92:5001/music",
            "https://syn4-l5bb577of66bb7naliv6zum7de-210-187-192-92.steventong.direct.quickconnect.to:15001/music",
            "https://syn4-l5bb577of66bb7naliv6zum7de-210-187-192-92.steventong.direct.quickconnect.to:5001/music",
            "https://209.58.169.44:443/music",
            "https://[2001:e68:541b:b473:211:32ff:fed5:a5ab]:15001/music",
            "https://[2001:e68:541b:b473:211:32ff:fed5:a5ab]:5001/music",
            "https://syn6-4674d65jyhgw5qbkfcwolaqqlaeaaq42cudo2hgaqrgl775vnfvm.steventong.direct.quickconnect.to:15001/music",
            "https://syn6-4674d65jyhgw5qbkfcwolaqqlaeaaq42cudo2hgaqrgl775vnfvm.steventong.direct.quickconnect.to:5001/music",
            "https://synr-sg4.STEVENTONG.direct.quickconnect.to:39446/music",
            "https://[2001:df1:800:c001:1::]:39446/music",
        ])
    }

    func testGetDeviceConnectionUsesRedirectPrefixAndCustomPingPongPath() async throws {
        let transport = HTTPClientFactorySpy()
        let apiClient = ApiClient(httpClientFactory: transport.makeFactory())
        let quickConnectApi = QuickConnectClient(
            apiClient: apiClient,
            pingpong: PingPong(apiClient: apiClient, timeout: 2),
            timeout: 2,
            keyValueStorage: MockKeyValueStorage()
        )

        transport.handler = { request, _ in
            let url = try XCTUnwrap(request.url)

            if url.path == "/Serv.php" {
                let body = try XCTUnwrap(requestBodyData(request))
                let parameters = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(parameters["id"] as? String, "audio_https")
                if parameters["command"] as? String == "request_tunnel" {
                    XCTAssertNotNil(parameters["location"] as? String)
                    XCTAssertTrue((parameters["platform"] as? String)?.isEmpty == false)
                    return (
                        try makeJSONData([
                            "command": "request_tunnel",
                            "version": 1,
                            "errno": 0,
                            "server": [
                                "redirect_prefix": "music",
                                "pingpong_path": "probe/pingpong.cgi?action=cors&quickconnect=true",
                            ],
                            "service": [
                                "relay_dn": "relay.quickconnect.to",
                                "relay_port": 443,
                            ],
                        ]),
                        makeHTTPURLResponse(url: url)
                    )
                }

                XCTAssertNil(parameters["location"])
                XCTAssertNil(parameters["platform"])
                return (
                    try makeJSONData([
                        "command": "get_server_info",
                        "version": 1,
                        "errno": 0,
                        "server": [
                            "redirect_prefix": "music",
                            "pingpong_path": "probe/pingpong.cgi?action=cors&quickconnect=true",
                            "interface": [["ip": "192.168.0.5"]],
                        ],
                        "service": [
                            "port": 5001,
                        ],
                    ]),
                    makeHTTPURLResponse(url: url)
                )
            }

            XCTAssertEqual(
                url.absoluteString,
                "https://192.168.0.5:5001/music/probe/pingpong.cgi?action=cors&quickconnect=true"
            )
            return (
                try makeJSONData(["success": true]),
                makeHTTPURLResponse(url: url)
            )
        }

        let connection = try await quickConnectApi.getDeviceConnection(quickConnectId: "demoqc", usesHTTPS: true)

        XCTAssertEqual(connection.type, .lan)
        XCTAssertEqual(connection.url, "https://192.168.0.5:5001/music")
    }
}
