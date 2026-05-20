import Foundation

// MARK: - ApiClientState

/// API 客户端状态容器（线程安全）
/// Thread-safe API client state container
///
/// 使用 `NSLock` 保护所有可变状态，支持并发读写。
/// Uses `NSLock` to protect all mutable state, supporting concurrent read/write.
///
/// 管理以下状态：
/// Manages the following states:
/// - 连接信息（连接类型 + 服务器地址）/ Connection info (type + URL)
/// - 会话信息（SID + DID）/ Session info (SID + DID)
/// - 拦截器列表 / Interceptor list
/// - API 信息提供者 / API info provider
final class ApiClientState {
    private let lock = NSLock()
    private var storedConnection: (type: ConnectionType, url: String)?
    private var storedSession: (sid: String, did: String?)?
    private var storedInterceptors: [RequestInterceptor] = []
    private var storedApiInfoProvider: ApiInfoProviding?

    /// 当前连接信息（线程安全读取）
    /// Current connection info (thread-safe read)
    var connection: (type: ConnectionType, url: String)? {
        lock.withLock { storedConnection }
    }

    /// 当前会话信息（线程安全读取）
    /// Current session info (thread-safe read)
    var session: (sid: String, did: String?)? {
        lock.withLock { storedSession }
    }

    var sessionSummary: String {
        lock.withLock {
            Logger.sessionSummary(sid: storedSession?.sid, did: storedSession?.did)
        }
    }

    var connectionSummary: String {
        lock.withLock {
            Logger.connectionSummary(url: storedConnection?.url)
        }
    }

    /// API 信息提供者（线程安全读写）
    /// API info provider (thread-safe read/write)
    var apiInfoProvider: ApiInfoProviding? {
        get { lock.withLock { storedApiInfoProvider } }
        set { lock.withLock { storedApiInfoProvider = newValue } }
    }

    /// 更新连接信息
    /// Update connection info
    func updateConnection(type: ConnectionType, url: String) {
        lock.withLock {
            storedConnection = (type, url)
        }
    }

    /// 更新会话信息
    /// Update session info
    func updateSession(sid: String, did: String?) {
        lock.withLock {
            storedSession = (sid, did)
        }
    }

    /// 清除会话信息
    /// Clear session info
    func clearSession() {
        lock.withLock {
            storedSession = nil
        }
    }

    /// 注册拦截器
    /// Register interceptor
    func addInterceptor(_ interceptor: RequestInterceptor) {
        lock.withLock {
            storedInterceptors.append(interceptor)
        }
    }

    /// 获取当前拦截器列表快照（线程安全）
    /// Get a snapshot of current interceptors (thread-safe)
    func interceptorsSnapshot() -> [RequestInterceptor] {
        lock.withLock { storedInterceptors }
    }
}

// MARK: - NSLock Extension

private extension NSLock {
    /// 在持有锁的情况下执行 body 闭包（支持 rethrows）
    /// Execute body closure while holding the lock (supports rethrows)
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
