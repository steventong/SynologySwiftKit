import Foundation

struct SynologyErrorMapper {
    func map(_ error: URLError) -> SynologyError {
        switch error.code {
        case .secureConnectionFailed:
            Logger.error("secureConnectionFailed ssl error, \(error.localizedDescription)")
            return .network(message: "Connection failed: \(error.localizedDescription)")
        case .cannotFindHost:
            Logger.error("cannotFindHost error, \(error.localizedDescription)")
            return .network(message: "Connection failed: \(error.localizedDescription)")
        case .timedOut:
            Logger.error("timeout error, \(error.localizedDescription)")
            return .network(message: "Request timeout")
        default:
            Logger.error("http error, \(error.localizedDescription)")
            return .network(message: error.localizedDescription)
        }
    }

    func throwBusinessError(code errorCode: Int) throws -> Never {
        let sessionErrorCodes: Set<Int> = [105, 106, 107, 119]

        if sessionErrorCodes.contains(errorCode) {
            let message = SynologyErrorCodeMapper.description(for: errorCode) ?? "Session error"
            throw SynologyError.sessionExpired(code: errorCode, message: message)
        }

        if errorCode >= 120 && errorCode <= 149 {
            throw SynologyError.api(code: errorCode, message: "Preserve for other purpose.")
        }

        let message = SynologyErrorCodeMapper.description(for: errorCode) ?? "errorCode = \(errorCode)"
        throw SynologyError.api(code: errorCode, message: message)
    }
}
