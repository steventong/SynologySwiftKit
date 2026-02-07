import Foundation

protocol HTTPTransporting {
    func send(
        _ request: URLRequest,
        timeout: TimeInterval,
        trustedSSLDomain: String?
    ) async throws -> (Data, URLResponse)
}
