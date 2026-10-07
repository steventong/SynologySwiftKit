import XCTest
@testable import SynologySwiftKit

final class ApiInfoApiHappyPathTests: XCTestCase {
    func testCancelledWaiterDoesNotCancelSharedDiscovery() async throws {
        let started = expectation(description: "Discovery suspended")
        let gate = RouteDiscoveryGate(started: started)
        let provider = ApiInfoApi(apiClient: SuspendedRouteClient(gate: gate), keyValueStorage: MockKeyValueStorage())
        provider.selectServer("nas-a.local")
        let first = Task { try await provider.refresh() }
        await fulfillment(of: [started], timeout: 2)
        first.cancel()
        let second = Task { try await provider.refresh() }
        await gate.release()
        do { try await first.value; XCTFail("Cancelled waiter must not receive the result") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await second.value
    }

    func testSwitchingServersRejectsLateDiscoveryEvenWhenSwitchingBack() async throws {
        let started = expectation(description: "Discovery suspended")
        let gate = RouteDiscoveryGate(started: started)
        let api = SuspendedRouteClient(gate: gate)
        let storage = MockKeyValueStorage()
        let provider = ApiInfoApi(apiClient: api, keyValueStorage: storage)
        provider.selectServer("nas-a.local")
        let old = Task { try await provider.refresh() }
        await fulfillment(of: [started], timeout: 2)
        provider.selectServer("nas-b.local")
        provider.selectServer("nas-a.local")
        await gate.release()
        do { try await old.value; XCTFail("Late discovery must be cancelled") }
        catch { XCTAssertTrue(error is CancellationError) }
        let replacement = MockApiClient()
        replacement.connection = (.custom_domain, "https://nas-a.local")
        replacement.mockResponse = routes("fresh.cgi")
        let reopened = ApiInfoApi(apiClient: replacement, keyValueStorage: storage)
        reopened.selectServer("nas-a.local")
        let fresh = try await reopened.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(fresh.path, "fresh.cgi")
        XCTAssertEqual(replacement.requestedEndpoints.count, 1)
    }

    func testRefreshFetchesOnceAndPersistsForTheSameServer() async throws {
        let api = MockApiClient()
        api.connection = (.custom_domain, "https://nas.local")
        api.mockResponse = routes("entry.cgi")
        let storage = MockKeyValueStorage()
        let first = ApiInfoApi(apiClient: api, keyValueStorage: storage)
        first.selectServer("NAS.local")
        try await first.refresh()
        let second = ApiInfoApi(apiClient: api, keyValueStorage: storage)
        second.selectServer("nas.local")
        try await second.loadFromCacheOrRefresh()
        let node = try await second.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(node.path, "entry.cgi")
        XCTAssertEqual(api.requestedEndpoints.count, 1)
        XCTAssertEqual(api.requestedEndpoints.first?.parameters["query"]?.stringValue, "all")
    }

    func testDifferentServersNeverShareRoutesAndSwitchingBackReusesCache() async throws {
        let api = MockApiClient()
        api.connection = (.custom_domain, "https://nas-a.local")
        let provider = ApiInfoApi(apiClient: api, keyValueStorage: MockKeyValueStorage())
        provider.selectServer("nas-a.local")
        api.mockResponse = routes("a.cgi")
        try await provider.refresh()
        provider.selectServer("nas-b.local")
        api.connection = (.custom_domain, "https://nas-b.local")
        api.mockResponse = routes("b.cgi")
        let b = try await provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(b.path, "b.cgi")
        provider.selectServer("nas-a.local")
        let a = try await provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(a.path, "a.cgi")
        XCTAssertEqual(api.requestedEndpoints.count, 2)
    }

    func testQuickConnectEndpointChangesReuseIdentityAndForcedRefreshUpdatesRoutes() async throws {
        let api = MockApiClient()
        api.connection = (.lan, "https://192.168.1.2:5001")
        api.mockResponse = routes("old.cgi")
        let provider = ApiInfoApi(apiClient: api, keyValueStorage: MockKeyValueStorage())
        provider.selectServer("QC123456")
        try await provider.refresh()
        api.connection = (.custom_domain, "https://remote.local")
        try await provider.loadFromCacheOrRefresh()
        XCTAssertEqual(api.requestedEndpoints.count, 1)
        api.mockResponse = routes("new.cgi")
        try await provider.refresh()
        let node = try await provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(node.path, "new.cgi")
        XCTAssertEqual(api.requestedEndpoints.count, 2)
    }

    func testConcurrentCacheMissesShareDiscovery() async throws {
        let api = MockApiClient()
        api.connection = (.custom_domain, "https://nas.local")
        api.mockResponse = routes("entry.cgi")
        let provider = ApiInfoApi(apiClient: api, keyValueStorage: MockKeyValueStorage())
        async let a = provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        async let b = provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        let results = try await [a, b]
        XCTAssertEqual(results.map(\.path), ["entry.cgi", "entry.cgi"])
        XCTAssertEqual(api.requestedEndpoints.count, 1)
    }

    func testLegacyGlobalCacheIsNotUsedForAnUnknownServer() async throws {
        let api = MockApiClient()
        api.connection = (.custom_domain, "https://new.local")
        api.mockResponse = routes("new.cgi")
        let storage = MockKeyValueStorage()
        storage.setCodable(routes("wrong.cgi"), forKey: "SynologySwiftKit_DiskStation_ApiInfo")
        let provider = ApiInfoApi(apiClient: api, keyValueStorage: storage)
        let node = try await provider.getApiInfoByApiName(apiName: "SYNO.DSM.Info")
        XCTAssertEqual(node.path, "new.cgi")
        XCTAssertEqual(api.requestedEndpoints.count, 1)
    }

    private func routes(_ path: String) -> [String: ApiInfoNode] {
        ["SYNO.DSM.Info": ApiInfoNode(path: path, minVersion: 2, maxVersion: 2, requestFormat: nil)]
    }
}

private actor RouteDiscoveryGate {
    let started: XCTestExpectation
    var continuation: CheckedContinuation<Void, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }
    func release() { continuation?.resume(); continuation = nil }
}

private final class SuspendedRouteClient: ApiRequestSending, ConnectionStateProviding {
    let gate: RouteDiscoveryGate
    var connection: (type: ConnectionType, url: String)? { (.custom_domain, "https://nas-a.local") }
    init(gate: RouteDiscoveryGate) { self.gate = gate }
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        await gate.wait()
        return ["SYNO.DSM.Info": ApiInfoNode(path: "stale.cgi", minVersion: 2, maxVersion: 2, requestFormat: nil)] as! T
    }
    func requestEnvelope<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T { try await request(endpoint) }
}
