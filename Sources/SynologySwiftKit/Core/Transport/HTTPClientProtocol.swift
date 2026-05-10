import Foundation

// MARK: - HTTPClientProtocol

/// HTTP 传输层协议（可替换实现以支持测试 / 自定义 URLSession）
/// HTTP transport protocol (replaceable for testing or custom URLSession)
///
/// SDK 默认使用 `URLSessionHTTPClient`。
/// SDK uses `URLSessionHTTPClient` by default.
///
/// 使用示例 / Usage:
/// ```swift
/// let client = SynologyClient(httpClient: MyMockHTTPClient())
/// ```
public protocol HTTPClientProtocol: Sendable {
    /// 发送 HTTP 请求
    /// Send HTTP request
    /// - Parameters:
    ///   - request: 已构建的 URLRequest / Built URLRequest
    ///   - timeout: 超时时间（秒）/ Timeout in seconds
    ///   - trustedSSLDomain: 可信 SSL 域名（用于自签名证书场景，传 nil 则使用系统默认证书验证）
    ///                        Trusted SSL domain (for self-signed certs; nil uses default system validation)
    /// - Returns: 响应数据 + URLResponse / Response data + URLResponse
    /// - Throws: 网络错误（URLError 等）/ Network error (URLError, etc.)
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse)
}
