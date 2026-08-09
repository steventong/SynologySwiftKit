import Foundation
import SwiftHttpClient

/// Factory for creating request-scoped HTTP clients.
///
/// Request-scoped creation keeps per-endpoint timeout and server trust behavior
/// without sharing mutable transport state across concurrent requests.
public typealias SynologyHTTPClientFactory = @Sendable (TimeInterval, ServerTrustPolicy) -> HTTPClient

/// Default request-scoped HTTP client factory backed by `SwiftHttpClient.HTTPClient`.
public let defaultSynologyHTTPClientFactory: SynologyHTTPClientFactory = { timeout, serverTrustPolicy in
    HTTPClient(timeout: timeout, serverTrustPolicy: serverTrustPolicy)
}
