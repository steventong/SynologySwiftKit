import Foundation

public protocol HTTPTransporting: Sendable {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse)
}
