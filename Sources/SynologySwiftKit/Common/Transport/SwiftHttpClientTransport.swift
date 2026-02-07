import Foundation
import SwiftHttpClient

/// Transport adapter that keeps SwiftHttpClient dependency at transport layer only.
struct SwiftHttpClientTransport: HTTPTransporting {
    func send(_ request: URLRequest,
              timeout: TimeInterval,
              trustedSSLDomain: String?) async throws -> (Data, URLResponse) {
        let client = SwiftHttpClient.HTTPClient(timeout: timeout, trustedSSLDomain: trustedSSLDomain)

        do {
            return try await client.send(request)
        } catch let error as SwiftHttpClient.HTTPClientError {
            throw mapHTTPClientError(error)
        }
    }

    private func mapHTTPClientError(_ error: SwiftHttpClient.HTTPClientError) -> SynologyError {
        switch error {
        case .invalidResponse:
            return .network(.invalidResponse)
        case let .httpStatus(code):
            return .network(.httpStatus(code: code))
        case let .decodingFailed(message):
            return .network(.decodingFailed(message: message))
        }
    }
}
