import Foundation

// MARK: - SynologyErrorMapper

/// URL 错误映射器
/// URL error mapper
///
/// 将 Foundation `URLError` 转换为语义更明确的 `SynologyError`。
/// Converts Foundation `URLError` into more semantically clear `SynologyError`.
struct SynologyErrorMapper {
    /// 将 URLError 映射为 SynologyError
    /// Map URLError to SynologyError
    /// - Parameter error: Foundation URLError / Foundation URLError
    /// - Returns: 对应的 SynologyError / Corresponding SynologyError
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

    /// 根据业务错误码抛出对应的 SynologyError
    /// Throw the corresponding SynologyError based on business error code
    ///
    /// - Session 相关错误码（105/106/107/119）映射为 `.sessionExpired`
    ///   Session-related codes (105/106/107/119) map to `.sessionExpired`
    /// - 120-149 保留错误码映射为 `.api`
    ///   Reserved codes 120-149 map to `.api`
    /// - 其余错误码通过 `SynologyErrorCodeMapper` 获取描述后映射为 `.api`
    ///   Other codes are mapped to `.api` with description from `SynologyErrorCodeMapper`
    ///
    /// - Parameter errorCode: 业务错误码 / Business error code
    /// - Throws: `SynologyError` 对应类型 / Corresponding `SynologyError` type
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
