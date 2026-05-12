import Foundation
import SwiftHttpClient

/// Factory for creating request-scoped HTTP clients.
///
/// Request-scoped creation keeps per-endpoint timeout and trusted SSL domain behavior
/// without sharing mutable transport state across concurrent requests.
public typealias SynologyHTTPClientFactory = @Sendable (TimeInterval, String?) -> HTTPClient

/// Default request-scoped HTTP client factory backed by `SwiftHttpClient.HTTPClient`.
public let defaultSynologyHTTPClientFactory: SynologyHTTPClientFactory = { timeout, trustedSSLDomain in
    HTTPClient(timeout: timeout, trustedSSLDomain: trustedSSLDomain)
}
