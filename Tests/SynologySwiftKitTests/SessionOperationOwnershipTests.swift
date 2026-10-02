import XCTest
@testable import SynologySwiftKit

final class SessionOperationOwnershipTests: XCTestCase {
    func testNewOperationWaitsForCancelledOperationsRollback() async throws {
        let owner = SessionOperationCoordinator()
        let started = expectation(description: "Old operation suspended")
        let pause = IgnoringCancellationGate(started: started)
        let state = TestState()
        let old = owner.start {
            try owner.commit { state.events.append("temporary") }
            await pause.wait()
            do { try owner.commit { state.events.append("stale commit") } }
            catch {
                owner.rollback { state.events.append("rollback") }
                throw error
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let new = owner.start { try owner.commit { state.events.append("new") } }
        await pause.release()
        do { try await old.value; XCTFail("Superseded operation must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await new.value
        XCTAssertEqual(state.events, ["temporary", "rollback", "new"])
    }

    func testExternalReplacementRejectsBothLateCommitAndRollback() async {
        let owner = SessionOperationCoordinator()
        let started = expectation(description: "Old operation suspended")
        let pause = IgnoringCancellationGate(started: started)
        let state = TestState()
        let old = owner.start {
            await pause.wait()
            do { try owner.commit { state.events.append("stale commit") } }
            catch {
                owner.rollback { state.events.append("stale rollback") }
                throw error
            }
        }
        await fulfillment(of: [started], timeout: 2)
        owner.replaceState { state.events.append("replacement") }
        await pause.release()
        _ = try? await old.value
        XCTAssertEqual(state.events, ["replacement"])
    }

    func testCancelledQueuedOperationReleasesRequestWaiters() async {
        let owner = SessionOperationCoordinator()
        let started = expectation(description: "Predecessor suspended")
        let pause = IgnoringCancellationGate(started: started)
        let first = owner.start { await pause.wait() }
        await fulfillment(of: [started], timeout: 2)
        let queued = owner.start { XCTFail("Cancelled queued work must not start") }
        queued.cancel()
        await pause.release()
        _ = try? await first.value
        _ = try? await queued.value
        let resumed = expectation(description: "Request barrier released")
        let waiter = Task { _ = try? await owner.requestStamp(); resumed.fulfill() }
        await fulfillment(of: [resumed], timeout: 2)
        waiter.cancel()
        await waiter.value
    }

    func testNestedAuthenticationSharesTheOuterOperation() async throws {
        let owner = SessionOperationCoordinator()
        let state = TestState()
        try await owner.perform {
            try await owner.perform { try owner.commit { state.events.append("nested") } }
            try owner.commit { state.events.append("outer") }
        }
        XCTAssertEqual(state.events, ["nested", "outer"])
    }

    func testOldResponseCannotInvalidateReplacementSession() async throws {
        let owner = SessionOperationCoordinator()
        let state = TestState()
        let stamp = try await owner.requestStamp()
        try await owner.withRequest(stamp: stamp) {
            owner.replaceState { state.events.append("new session") }
            owner.mutateForCurrentRequest { state.events.append("stale expiry") }
        }
        XCTAssertEqual(state.events, ["new session"])
        XCTAssertThrowsError(try owner.validateRequest(stamp))
    }

    func testBackgroundOptimizationWaitsForItsOwnParent() async throws {
        let owner = SessionOperationCoordinator()
        let child = ChildOperation()
        let state = TestState()
        try await owner.perform {
            let task = Task {
                try await owner.performAfterCurrent {
                    try await owner.perform { try owner.commit { state.events.append("child") } }
                }
            }
            await child.set(task)
            try owner.commit { state.events.append("parent") }
        }
        try await child.finish()
        XCTAssertEqual(state.events, ["parent", "child"])
    }

    func testBackgroundDiscoveryDoesNotBlockOrdinaryRequests() async throws {
        let owner = SessionOperationCoordinator()
        let child = ChildOperation()
        let started = expectation(description: "Background discovery started")
        let pause = IgnoringCancellationGate(started: started)
        try await owner.perform {
            let task = Task {
                try await owner.performAfterCurrent { await pause.wait() }
            }
            await child.set(task)
        }
        await fulfillment(of: [started], timeout: 2)
        let completed = expectation(description: "Request proceeds during discovery")
        let request = Task {
            _ = try await owner.requestStamp()
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 2)
        await pause.release()
        try await child.finish()
        try await request.value
    }

    func testLateLogoutResponseCannotClearAnExternallyReplacedSession() async throws {
        let owner = SessionOperationCoordinator()
        let started = expectation(description: "Logout in flight")
        let pause = IgnoringCancellationGate(started: started)
        let api = DeferredSessionAPI()
        api.session = ("old", nil)
        api.response = { _ in await pause.wait(); return EmptyData() }
        let storage = makeKeyChainStorage(service: UUID().uuidString)
        storage.saveSessionInfo(sid: "old", did: nil)
        let auth = AuthClient(apiClient: api, keyChainStorage: storage, sessionOperations: owner)
        let logout = Task { try await auth.logout() }
        await fulfillment(of: [started], timeout: 2)
        owner.replaceState {
            api.updateSession(sid: "new", did: nil)
            storage.saveSessionInfo(sid: "new", did: nil)
        }
        await pause.release()
        do { try await logout.value; XCTFail("Old logout must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(api.session?.sid, "new")
        XCTAssertEqual(storage.getSessionInfo()?.sid, "new")
    }

    func testSupersededLoginDoesNotOverwriteNewCredentialsOrDeviceToken() async {
        let owner = SessionOperationCoordinator()
        let started = expectation(description: "Old login in flight")
        let pause = IgnoringCancellationGate(started: started)
        let api = DeferredSessionAPI()
        api.connection = (.custom_domain, "https://original.invalid")
        api.session = ("original", nil)
        api.response = { endpoint in
            let username = endpoint.parameters["account"]?.stringValue ?? ""
            if username == "old" { await pause.wait() }
            return AuthResult(did: "\(username)-device", isPortalPort: false, sid: "\(username)-sid", synotoken: nil)
        }
        let storage = makeKeyChainStorage(service: UUID().uuidString)
        storage.saveSessionInfo(sid: "original", did: nil)
        let login = SynologyUserLogin(
            apiInfoApi: NoopAPIInfo(), apiClient: api,
            authApi: AuthClient(apiClient: api, keyChainStorage: storage, sessionOperations: owner),
            audioStationApi: AudioStationClient(apiClient: api),
            connectionChecker: TestConnectionChecker(), keyChainStorage: storage,
            sessionOperations: owner
        )
        let first = login.login(server: "https://old.invalid", username: "old", password: "test")
        let oldResult = Task { await self.collect(first) }
        await fulfillment(of: [started], timeout: 2)
        let second = login.login(server: "https://new.invalid", username: "new", password: "test")
        let newResult = Task { await self.collect(second) }
        await pause.release()
        let oldEvents = await oldResult.value
        let newEvents = await newResult.value
        XCTAssertFalse(oldEvents.contains { if case .completed = $0 { return true }; return false })
        XCTAssertTrue(newEvents.contains { if case .completed = $0 { return true }; return false })
        XCTAssertEqual(api.connection?.url, "https://new.invalid")
        XCTAssertEqual(api.session?.sid, "new-sid")
        XCTAssertEqual(storage.getSessionInfo()?.sid, "new-sid")
        XCTAssertEqual(storage.getCredentials()?.username, "new")
        XCTAssertEqual(storage.getDeviceInfo()?.0, "new-device")
    }

    func testLateMediaResponseIsRejectedByTheActualRequestExecutor() async {
        let transport = HTTPClientFactorySpy()
        let client = ApiClient(httpClientFactory: transport.makeFactory(), keyValueStorage: MockKeyValueStorage())
        let started = expectation(description: "HTTP media request started")
        let release = DispatchSemaphore(value: 0)
        transport.handler = { request, _ in
            started.fulfill()
            guard release.wait(timeout: .now() + 2) == .success else {
                throw SynologyError.network(message: "Fixture timed out")
            }
            return (Data([1, 2, 3]), makeHTTPURLResponse(url: request.url!))
        }
        let request = Task { try await client.fetchMediaData(url: URL(string: "https://old.invalid/artwork")!) }
        await fulfillment(of: [started], timeout: 2)
        client.sessionOperations.replaceState { client.updateSession(sid: "replacement", did: nil) }
        release.signal()
        do { _ = try await request.value; XCTFail("Stale media must not escape the SDK") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(client.session?.sid, "replacement")
    }

    func testSessionGetterDoesNotResurrectPreviouslyClearedMemoryState() {
        let storage = makeKeyChainStorage(service: UUID().uuidString)
        storage.saveSessionInfo(sid: "persisted", did: nil)
        let client = SynologyClient(keyValueStorage: MockKeyValueStorage(), keyChainStorage: storage)
        XCTAssertEqual(client.session.current?.sid, "persisted")
        client.session.clear()
        XCTAssertNil(storage.getSessionInfo())
        storage.saveSessionInfo(sid: "stale-cache", did: nil)
        XCTAssertNil(client.session.current)
    }

    func testCombinedConfigurationInvalidatesOldOperationRollback() async {
        let storage = makeKeyChainStorage(service: UUID().uuidString)
        let client = SynologyClient(keyValueStorage: MockKeyValueStorage(), keyChainStorage: storage)
        let owner = client.apiClient.sessionOperations
        let started = expectation(description: "Old connection operation suspended")
        let pause = IgnoringCancellationGate(started: started)
        let old = owner.start {
            try owner.commit { client.apiClient.updateConnection(type: .custom_domain, url: "https://temporary.invalid") }
            await pause.wait()
            owner.rollback { client.apiClient.updateConnection(type: .custom_domain, url: "https://old.invalid") }
        }
        await fulfillment(of: [started], timeout: 2)
        client.configureConnection(type: .custom_domain, url: "https://new.invalid", sid: "new", did: "device")
        await pause.release()
        _ = try? await old.value
        XCTAssertEqual(client.session.connection?.url, "https://new.invalid")
        XCTAssertEqual(client.session.current?.sid, "new")
        XCTAssertEqual(client.session.current?.did, "device")
        XCTAssertEqual(storage.getConnectionInfo()?.url, "https://new.invalid")
    }

    func testPublicSessionDoesNotExposeATentativeAuthenticationEndpoint() async throws {
        let client = SynologyClient(keyValueStorage: MockKeyValueStorage(), keyChainStorage: makeKeyChainStorage(service: UUID().uuidString))
        client.configureConnection(type: .custom_domain, url: "https://committed.invalid", sid: "committed")
        let owner = client.apiClient.sessionOperations
        let started = expectation(description: "Tentative endpoint")
        let pause = IgnoringCancellationGate(started: started)
        let operation = owner.start {
            try owner.commit { client.apiClient.updateConnection(type: .custom_domain, url: "https://next.invalid") }
            await pause.wait()
            try owner.commit { client.apiClient.updateSession(sid: "next", did: nil) }
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(client.session.connection?.url, "https://committed.invalid")
        XCTAssertEqual(client.session.current?.sid, "committed")
        await pause.release()
        try await operation.value
        XCTAssertEqual(client.session.connection?.url, "https://next.invalid")
        XCTAssertEqual(client.session.current?.sid, "next")
    }

    func testFinalStateIsVisibleBeforeTheOperationEmitsItsResult() async throws {
        let client = SynologyClient(keyValueStorage: MockKeyValueStorage(), keyChainStorage: makeKeyChainStorage(service: UUID().uuidString))
        let owner = client.apiClient.sessionOperations
        let observed = try await owner.perform {
            try owner.commitState {
                client.apiClient.updateConnection(type: .custom_domain, url: "https://committed.invalid")
                client.apiClient.updateSession(sid: "committed", did: nil)
            }
            return client.session.current?.sid
        }
        XCTAssertEqual(observed, "committed")
    }

    private func collect(_ stream: AsyncStream<SynologyUserLoginProgress>) async -> [SynologyUserLoginProgress] {
        var result: [SynologyUserLoginProgress] = []
        for await event in stream { result.append(event) }
        return result
    }
}

private final class TestState { var events: [String] = [] }
private actor IgnoringCancellationGate {
    let started: XCTestExpectation
    var continuation: CheckedContinuation<Void, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func wait() async {
        await withCheckedContinuation { continuation in self.continuation = continuation; started.fulfill() }
    }
    func release() { continuation?.resume(); continuation = nil }
}
private actor ChildOperation {
    var task: Task<Void, Error>?
    func set(_ task: Task<Void, Error>) { self.task = task }
    func finish() async throws { try await task?.value }
}
private final class DeferredSessionAPI: ApiRequestSending, ConnectionStateProviding, ConnectionStateUpdating, SessionStateProviding, SessionStateUpdating, ApiURLBuilding {
    var connection: (type: ConnectionType, url: String)?
    var session: (sid: String, did: String?)?
    var response: (ApiEndpoint) async throws -> Any = { _ in EmptyData() }
    func updateConnection(type: ConnectionType, url: String) { connection = (type, url) }
    func updateSession(sid: String, did: String?) { session = (sid, did) }
    func clearSession() { session = nil }
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T {
        guard let value = try await response(endpoint) as? T else { throw SynologyError.network(message: "Unexpected fixture response") }
        return value
    }
    func requestEnvelope<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T { try await request(endpoint) }
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL { URL(string: "https://fixture.invalid")! }
}
private struct NoopAPIInfo: ApiInfoProviding {
    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode { ApiInfoNode(path: "entry.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil) }
    func refresh() async throws {}
    func loadFromCacheOrRefresh() async throws {}
}
private struct TestConnectionChecker: ConnectionChecking {
    func check() -> AsyncStream<ConnectionCheckProgress> { check(server: "https://fixture.invalid") }
    func check(server: String) -> AsyncStream<ConnectionCheckProgress> {
        AsyncStream { $0.yield(.success(connection: SynologyConnection(type: .custom_domain, url: server), usedCachedConnection: false)); $0.finish() }
    }
    func check(server: String, usesHTTPS: Bool) -> AsyncStream<ConnectionCheckProgress> { check(server: server) }
}
