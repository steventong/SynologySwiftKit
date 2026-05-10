import Foundation

// MARK: - SynologyEnvelopeDecoder

/// Synology 响应信封解码器
/// Synology response envelope decoder
///
/// 提供对 `SynologyResponse<T>` 信封的统一拆包操作：
/// Provides unified unwrapping operations for `SynologyResponse<T>` envelopes:
/// - 成功时返回 data / Returns data on success
/// - 失败时抛出对应的 `SynologyError` / Throws corresponding `SynologyError` on failure
struct SynologyEnvelopeDecoder {
    /// 解包响应 data（失败时抛出错误）
    /// Unwrap response data (throws on failure)
    /// - Parameter response: Synology 响应信封 / Synology response envelope
    /// - Returns: 解包后的数据 / Unwrapped data
    /// - Throws: `SynologyError` 对应的业务错误 / Corresponding business error
    func unwrap<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) throws -> Value {
        try response.unwrap()
    }

    /// 判断响应是否成功
    /// Check whether the response is successful
    /// - Parameter response: Synology 响应信封 / Synology response envelope
    /// - Returns: 是否成功 / Whether successful
    func isSuccessful<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) -> Bool {
        response.success
    }

    /// 获取响应的错误码（成功时返回 nil）
    /// Get the error code from the response (nil if successful)
    /// - Parameter response: Synology 响应信封 / Synology response envelope
    /// - Returns: 错误码，成功时为 nil / Error code, nil if successful
    func errorCode<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) -> Int? {
        response.error?.code
    }
}
