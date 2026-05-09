import Foundation

public protocol HTTPClientProtocol: Sendable {
    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse)
}
