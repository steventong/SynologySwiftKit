import Foundation

enum SessionValidationOutcome: Sendable, Equatable {
    case valid
    case invalidSession(code: Int)
    case validationFailed
}

protocol ConnectionSessionValidating {
    func validateCurrentSession() async -> SessionValidationOutcome
}

struct DSMSessionValidator: ConnectionSessionValidating {
    private let dsmInfoApi: DSMInfoClient

    init(dsmInfoApi: DSMInfoClient) {
        self.dsmInfoApi = dsmInfoApi
    }

    func checkCurrentSession() async throws {
        try Task.checkCancellation()
        _ = try await dsmInfoApi.query()
        try Task.checkCancellation()
    }

    /// 校验失败只表示当前无法确认会话；仅服务器明确失效码可升级为重新登录。
    func validateCurrentSession() async -> SessionValidationOutcome {
        do {
            try await checkCurrentSession()
            return .valid
        } catch let SynologyError.sessionExpired(code, message) where SynologyError.sessionExpired(code: code, message: message).isServerSessionExpired {
            Logger.info("DSMSessionValidator#validateCurrentSession invalid session: \(code), \(message)")
            return .invalidSession(code: code)
        } catch {
            Logger.warn("DSMSessionValidator#validateCurrentSession failed: \(error)")
            return .validationFailed
        }
    }
}
