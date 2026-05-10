import Foundation

// MARK: - URLSessionHTTPClient

/// 基于 Foundation URLSession 的默认 HTTP 传输实现
/// Default SDK transport backed by Foundation URLSession
///
/// 每次请求基于 `timeout` 动态创建 `URLSession`，以支持不同接口的超时配置。
/// Creates a new `URLSession` per request based on `timeout` to support per-endpoint timeout config.
public struct URLSessionHTTPClient: HTTPClientProtocol {
    /// URLSession 工厂（通过超时时间创建合适的 URLSession）
    /// URLSession factory (creates URLSession based on timeout)
    private let sessionProvider: @Sendable (TimeInterval) -> URLSession

    /// 使用默认 URLSession 配置初始化
    /// Initialize with default URLSession configuration
    public init() {
        self.init { timeout in
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            return URLSession(configuration: configuration)
        }
    }

    /// 使用自定义 URLSession 工厂初始化（用于测试或自定义配置）
    /// Initialize with a custom URLSession factory (for testing or custom configuration)
    /// - Parameter sessionProvider: 根据超时时间创建 URLSession 的工厂闭包 / Factory closure for creating URLSession
    init(sessionProvider: @escaping @Sendable (TimeInterval) -> URLSession) {
        self.sessionProvider = sessionProvider
    }

    /// 发送 HTTP 请求（异步）
    /// Send HTTP request (async)
    ///
    /// 将 URLSession 的回调 API 桥接为 async/await。
    /// Bridges URLSession callback API to async/await.
    ///
    /// - Parameters:
    ///   - request: 已构建的 URLRequest / Built URLRequest
    ///   - timeout: 超时时间（秒），将用于创建对应的 URLSession / Timeout in seconds, used to create URLSession
    ///   - trustedSSLDomain: 可信 SSL 域名（当前实现暂不使用，由 URLSession 系统验证）
    ///                        Trusted SSL domain (not currently used; relies on system validation)
    /// - Returns: 响应体数据 + URLResponse / Response body data + URLResponse
    /// - Throws: URLError 或网络相关错误 / URLError or network-related error
    public func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        let session = sessionProvider(timeout)
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(throwing: SynologyError.network(message: "invalid response"))
                    return
                }

                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
