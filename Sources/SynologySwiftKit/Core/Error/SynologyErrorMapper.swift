import Foundation
import SwiftHttpClient

// MARK: - SynologyErrorMapper

/// URL 错误映射器
/// URL error mapper
///
/// 将 Foundation `URLError` 转换为语义更明确的 `SynologyError`。
/// Converts Foundation `URLError` into more semantically clear `SynologyError`.
/// 业务错误码映射请使用 `SynologyApiError.toSynologyError(from:)`。
/// For business error code mapping, use `SynologyApiError.toSynologyError(from:)`.
struct SynologyErrorMapper {
    func mapTransportError(_ error: Error) -> Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? URLError {
            return error.code == .cancelled ? CancellationError() : map(error)
        }
        if case let HTTPClientError.serverCertificateUntrusted(certificate) = error {
            return map(certificate)
        }
        return error
    }

    func map(_ certificate: ServerCertificateInfo) -> SynologyError {
        .serverCertificateUntrusted(SynologyServerCertificate(host: certificate.host, subject: certificate.subject,
                                                             sha256Fingerprint: certificate.sha256Fingerprint))
    }

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

}
