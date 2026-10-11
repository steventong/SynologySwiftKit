import Foundation

/// DSM internal API; availability and semantics depend on the target DSM version.
public final class DesktopTimeoutClient {
    private let apiClient: ApiRequestSending

    init(apiClient: ApiRequestSending) { self.apiClient = apiClient }

    /// Calls SYNO.Core.Desktop.Timeout.check (version 1).
    /// Omit sid to use the current session. Explicit sid is sent alone, without ambient cookies.
    /// Returns the API envelope, including failures, without invalidating the current session.
    public func check(sid: String? = nil) async throws -> DSMReadResponse {
        try await apiClient.requestEnvelope(ApiEndpoint(
            api: SynologyApi.Core.DESKTOP_TIMEOUT, method: "check", version: 1,
            httpMethod: .post, sidOnQuery: sid == nil, sidOnCookie: false
        ) {
            if let sid { ("_sid", sid) }
        })
    }
}
