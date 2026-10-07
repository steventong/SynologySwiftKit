import Foundation

/// Server-scoped route discovery. Password login refreshes routes; other requests reuse them.
final class ApiInfoApi: ApiInfoProviding {
    private let apiClient: ApiRequestSending & ConnectionStateProviding
    private let keyValueStorage: KeyValueStorage
    private let lock = NSLock()
    private var selectedServer: String?
    private var nodes: [String: [String: ApiInfoNode]] = [:]
    private var pending: [String: (UUID, Task<[String: ApiInfoNode], Error>)] = [:]

    init(apiClient: ApiRequestSending & ConnectionStateProviding, keyValueStorage: KeyValueStorage = StorageService()) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
    }

    var serverIdentity: String? { locked { selectedServer } }

    func selectServer(_ server: String?) {
        let identity = server.map(Self.identity)
        let cancelled = locked { () -> [Task<[String: ApiInfoNode], Error>] in
            guard selectedServer != identity else { return [] }
            selectedServer = identity
            let tasks = pending.values.map { $0.1 }
            pending.removeAll()
            return tasks
        }
        cancelled.forEach { $0.cancel() }
    }

    private static func identity(_ server: String) -> String {
        let value = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if QuickConnectUtils.isQuickConnectId(server: value) { return value.lowercased() }
        let address = (try? LoginServerAddressResolver.automaticAttempts(for: value).first?.server) ?? value
        guard var url = URLComponents(string: address) else { return address }
        url.scheme = url.scheme?.lowercased()
        url.host = url.host?.lowercased()
        url.user = nil
        url.password = nil
        url.query = nil
        url.fragment = nil
        if url.path == "/" { url.path = "" }
        return url.string ?? address
    }

    private func scope() throws -> String {
        if let identity = serverIdentity { return identity }
        guard let connection = apiClient.connection else { throw SynologyError.network(message: "Host not configured") }
        return Self.identity(connection.url)
    }

    private func storageKey(_ scope: String) -> String {
        "synology.api.routes." + Data(scope.utf8).base64EncodedString()
    }

    func getApiInfoByApiName(apiName: String) async throws -> ApiInfoNode {
        let routes = try await load(force: false)
        guard let node = routes[apiName] else {
            throw SynologyError.api(code: 102, message: "API not found: \(apiName)")
        }
        return node
    }

    func loadFromCacheOrRefresh() async throws { _ = try await load(force: false) }
    func refresh() async throws { _ = try await load(force: true) }

    private func load(force: Bool) async throws -> [String: ApiInfoNode] {
        try Task.checkCancellation()
        let scope = try scope()
        let result: (UUID, Task<[String: ApiInfoNode], Error>) = locked {
            if let task = pending[scope] { return task }
            if !force {
                if let cached = nodes[scope] { return (UUID(), Task { cached }) }
                if let cached: [String: ApiInfoNode] = keyValueStorage.codable(forKey: storageKey(scope)), !cached.isEmpty {
                    nodes[scope] = cached
                    return (UUID(), Task { cached })
                }
            }
            let id = UUID()
            let task = Task { [self] in
                let endpoint = ApiEndpoint(api: SynologyApi.Core.INFO, fullPath: "/webapi/query.cgi", httpMethod: .get) {
                    ("api", SynologyApi.Core.INFO.name)
                    ("version", 1)
                    ("method", "query")
                    ("query", "all")
                }
                let routes: [String: ApiInfoNode] = try await apiClient.request(endpoint)
                try Task.checkCancellation()
                guard !routes.isEmpty else { throw SynologyError.api(code: 102, message: "Empty API route table") }
                return routes
            }
            pending[scope] = (id, task)
            return (id, task)
        }
        do {
            // 路由发现由服务器身份管理；单个调用者结束不能取消其他调用者共用的查询。
            let routes = try await result.1.value
            guard try self.scope() == scope else { throw CancellationError() }
            locked {
                if pending[scope]?.0 == result.0 {
                    nodes[scope] = routes
                    keyValueStorage.setCodable(routes, forKey: storageKey(scope))
                    pending[scope] = nil
                }
            }
            try Task.checkCancellation()
            return routes
        } catch {
            locked { if pending[scope]?.0 == result.0 { pending[scope] = nil } }
            throw error
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
