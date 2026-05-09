import Foundation

final class ApiClientState {
    private let lock = NSLock()
    private var storedConnection: (type: ConnectionType, url: String)?
    private var storedSession: (sid: String, did: String?)?
    private var storedInterceptors: [RequestInterceptor] = []
    private var storedApiInfoProvider: ApiInfoProviding?

    var connection: (type: ConnectionType, url: String)? {
        lock.withLock { storedConnection }
    }

    var session: (sid: String, did: String?)? {
        lock.withLock { storedSession }
    }

    var apiInfoProvider: ApiInfoProviding? {
        get { lock.withLock { storedApiInfoProvider } }
        set { lock.withLock { storedApiInfoProvider = newValue } }
    }

    func updateConnection(type: ConnectionType, url: String) {
        lock.withLock {
            storedConnection = (type, url)
        }
    }

    func updateSession(sid: String, did: String?) {
        lock.withLock {
            storedSession = (sid, did)
        }
    }

    func clearSession() {
        lock.withLock {
            storedSession = nil
        }
    }

    func addInterceptor(_ interceptor: RequestInterceptor) {
        lock.withLock {
            storedInterceptors.append(interceptor)
        }
    }

    func interceptorsSnapshot() -> [RequestInterceptor] {
        lock.withLock { storedInterceptors }
    }
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
