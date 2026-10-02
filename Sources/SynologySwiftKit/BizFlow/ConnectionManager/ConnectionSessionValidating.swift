import Foundation

enum SessionValidationOutcome: Sendable, Equatable {
    case valid
    case invalidSession(code: Int)
    case validationFailed
}

protocol ConnectionSessionValidating {
    func validateCurrentSession() async -> SessionValidationOutcome
}

struct AudioStationSessionValidator: ConnectionSessionValidating {
    private let audioStationApi: AudioStationClient

    init(audioStationApi: AudioStationClient) {
        self.audioStationApi = audioStationApi
    }

    /// 校验失败只表示当前无法确认会话；仅服务器明确失效码可升级为重新登录。
    func validateCurrentSession() async -> SessionValidationOutcome {
        do {
            try Task.checkCancellation()
            _ = try await audioStationApi.info.query()
            try Task.checkCancellation()
            return .valid
        } catch let SynologyError.sessionExpired(code, message) where SynologyError.sessionExpired(code: code, message: message).isServerSessionExpired {
            Logger.info("AudioStationSessionValidator#validateCurrentSession invalid session: \(code), \(message)")
            return .invalidSession(code: code)
        } catch {
            Logger.warn("AudioStationSessionValidator#validateCurrentSession failed: \(error)")
            return .validationFailed
        }
    }
}
