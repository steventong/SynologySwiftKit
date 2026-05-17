import Foundation

enum SessionValidationOutcome: Sendable, Equatable {
    case valid
    case invalidSession
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

    func validateCurrentSession() async -> SessionValidationOutcome {
        do {
            _ = try await audioStationApi.info.query()
            return .valid
        } catch let SynologyError.sessionExpired(code, message) {
            Logger.info("AudioStationSessionValidator#validateCurrentSession invalid session: \(code), \(message)")
            return .invalidSession
        } catch {
            Logger.warn("AudioStationSessionValidator#validateCurrentSession failed: \(error)")
            return .validationFailed
        }
    }
}
