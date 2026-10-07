import XCTest
@testable import SynologySwiftKit

final class RouteCacheFlowTests: XCTestCase {
    func testLoginThenResumeRecoveryAndRelaunchReuseRoutesWithoutPing() async throws {
        let transport = HTTPClientFactorySpy()
        var calls: [String] = []
        transport.handler = { request, _ in
            let api = self.apiName(request)
            calls.append(api)
            return try self.response(request)
        }
        let storage = MockKeyValueStorage()
        let secrets = makeKeyChainStorage(service: UUID().uuidString)
        let client = makeClient(transport, storage, secrets)
        let loggedIn = await login(client)
        XCTAssertTrue(loggedIn)
        XCTAssertEqual(calls, ["SYNO.API.Info", "SYNO.API.Auth"])
        calls = []
        for await _ in client.flows.userLogin.resume() {}
        XCTAssertEqual(calls, ["SYNO.DSM.Info"])
        calls = []
        let recovery = await client.flows.connection.recover()
        XCTAssertEqual(recovery.status, .connected)
        XCTAssertEqual(calls, ["SYNO.DSM.Info"])
        calls = []
        let reopened = makeClient(transport, storage, secrets)
        let afterLaunch = await reopened.flows.connection.recover()
        XCTAssertEqual(afterLaunch.status, .connected)
        XCTAssertEqual(calls, ["SYNO.DSM.Info"])
        calls = []
        let secondLogin = await login(client)
        XCTAssertTrue(secondLogin)
        XCTAssertEqual(calls, ["SYNO.API.Info", "SYNO.API.Auth"])
    }

    func testOTPContinuationReusesDiscoveredRoutes() async throws {
        for server in ["https://nas.local", "nas.local"] {
            let transport = HTTPClientFactorySpy()
            var calls: [String] = []
            var needsOTP = true
            transport.handler = { request, _ in
                let api = self.apiName(request)
                calls.append(api)
                if server == "nas.local" && request.url?.scheme == "https" { throw URLError(.cannotConnectToHost) }
                if api == "SYNO.API.Auth" && needsOTP {
                    needsOTP = false
                    return (try makeJSONData(["success": false, "error": ["code": 403]]), makeHTTPURLResponse(url: request.url!))
                }
                return try self.response(request)
            }
            let client = makeClient(transport, MockKeyValueStorage(), makeKeyChainStorage(service: UUID().uuidString))
            var otpRequired = false
            for await progress in client.flows.userLogin.login(server: server, username: "tester", password: "secret") {
                if case .otpRequired = progress { otpRequired = true }
            }
            XCTAssertTrue(otpRequired)
            let success = await login(client, otp: "123456", server: server)
            XCTAssertTrue(success)
            XCTAssertEqual(calls, (server == "nas.local" ? ["SYNO.API.Info"] : []) + ["SYNO.API.Info", "SYNO.API.Auth", "SYNO.API.Auth"])
        }
    }

    func testRouteMismatchRefreshesAndRetriesOnlyOnce() async throws {
        for code in [102, 103, 104, 105, 106] {
            let transport = HTTPClientFactorySpy()
            var paths: [String] = []
            var routeFetches = 0
            transport.handler = { request, _ in
                let api = self.apiName(request)
                paths.append(request.url!.path)
                if api == "SYNO.API.Info" {
                    routeFetches += 1
                    return try self.response(request, route: routeFetches == 1 ? "old.cgi" : "new.cgi")
                }
                return (try makeJSONData(["success": false, "error": ["code": code]]), makeHTTPURLResponse(url: request.url!))
            }
            let client = makeClient(transport, MockKeyValueStorage(), makeKeyChainStorage(service: UUID().uuidString))
            client.configureConnection(type: .custom_domain, url: "https://nas.local", sid: "test-sid")
            do { _ = try await client.system.dsmInfo.query(); XCTFail("Expected failure") } catch {}
            let mismatch = [102, 103, 104].contains(code)
            XCTAssertEqual(routeFetches, mismatch ? 2 : 1)
            XCTAssertEqual(paths, mismatch ? ["/webapi/query.cgi", "/webapi/old.cgi", "/webapi/query.cgi", "/webapi/new.cgi"]
                           : ["/webapi/query.cgi", "/webapi/old.cgi"])
        }
    }

    private func login(_ client: SynologyClient, otp: String? = nil, server: String = "https://nas.local") async -> Bool {
        for await event in client.flows.userLogin.login(server: server, username: "tester", password: "secret", otpCode: otp) {
            if case .completed = event { return true }
        }
        return false
    }

    private func makeClient(_ transport: HTTPClientFactorySpy, _ storage: MockKeyValueStorage, _ secrets: KeyChainStorage) -> SynologyClient {
        SynologyClient(keyValueStorage: storage, keyChainStorage: secrets, httpClientFactory: transport.makeFactory())
    }

    private func apiName(_ request: URLRequest) -> String {
        let encoded = request.httpMethod == "GET" ? request.url!.query ?? "" : String(decoding: requestBodyData(request) ?? Data(), as: UTF8.self)
        return URLComponents(string: "https://test/?" + encoded)?.queryItems?.first { $0.name == "api" }?.value ?? "missing-api"
    }

    private func response(_ request: URLRequest, route: String = "entry.cgi") throws -> (Data, HTTPURLResponse) {
        let data: [String: Any]
        switch apiName(request) {
        case "SYNO.API.Info":
            data = ["SYNO.API.Auth": ["path": route, "minVersion": 3, "maxVersion": 7],
                    "SYNO.DSM.Info": ["path": route, "minVersion": 2, "maxVersion": 2]]
        case "SYNO.API.Auth": data = ["sid": "new-sid", "is_portal_port": false]
        case "SYNO.DSM.Info": data = ["model": "DS920+"]
        default: XCTFail("Unexpected request \(request.url!)"); data = [:]
        }
        return (try makeJSONData(["success": true, "data": data]), makeHTTPURLResponse(url: request.url!))
    }
}
