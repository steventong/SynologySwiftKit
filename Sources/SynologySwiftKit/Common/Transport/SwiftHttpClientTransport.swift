import Foundation
import SwiftHttpClient

/// Transport adapter that keeps SwiftHttpClient dependency at transport layer only.
struct SwiftHttpClientTransport: HTTPTransporting {
    typealias ClientFactory = (TimeInterval, String?) -> any SwiftHTTPClientSending

    private let clientFactory: ClientFactory

    init(clientFactory: @escaping ClientFactory = { timeout, trustedSSLDomain in
        SwiftHttpClient.HTTPClient(timeout: timeout, trustedSSLDomain: trustedSSLDomain)
    }) {
        self.clientFactory = clientFactory
    }

    func send(_ request: URLRequest, timeout: TimeInterval, trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
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

protocol SwiftHTTPClientSending {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension SwiftHttpClient.HTTPClient: SwiftHTTPClientSending {}
