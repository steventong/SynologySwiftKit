import Foundation

/// Default SDK transport backed by Foundation URLSession.
public struct URLSessionHTTPClient: HTTPClientProtocol {
    private let sessionProvider: @Sendable (TimeInterval) -> URLSession

    public init() {
        self.init { timeout in
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            return URLSession(configuration: configuration)
        }
    }

    init(sessionProvider: @escaping @Sendable (TimeInterval) -> URLSession) {
        self.sessionProvider = sessionProvider
    }

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
