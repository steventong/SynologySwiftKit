import Foundation
import SwiftHttpClient

/// Transport adapter that keeps SwiftHttpClient dependency at transport layer only.
public struct SwiftHttpClientAdapter: HTTPClientProtocol {
    typealias ClientFactory = @Sendable (TimeInterval, String?) -> any SwiftHTTPClientSending

    private let clientFactory: ClientFactory

    public init() {
        self.init(clientFactory: { timeout, trustedSSLDomain in
            SwiftHTTPClientBox(client: SwiftHttpClient.HTTPClient(timeout: timeout, trustedSSLDomain: trustedSSLDomain))
        })
    }

    init(clientFactory: @escaping ClientFactory) {
        self.clientFactory = clientFactory
    }

    public func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        let client = clientFactory(timeout, trustedSSLDomain)

        do {
            return try await client.send(request)
        } catch let error as SwiftHttpClient.HTTPClientError {
            throw mapHTTPClientError(error)
        }
    }

    private func mapHTTPClientError(_ error: SwiftHttpClient.HTTPClientError) -> SynologyError {
        switch error {
        case .invalidResponse:
            return .network(message: "invalid response")
        case let .httpStatus(code):
            return .network(message: "http status: \(code)")
        case let .decodingFailed(message):
            return .network(message: "decoding failed: \(message)")
        }
    }
}

protocol SwiftHTTPClientSending: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

private struct SwiftHTTPClientBox: SwiftHTTPClientSending, @unchecked Sendable {
    let client: SwiftHttpClient.HTTPClient

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await client.send(request)
    }
}
