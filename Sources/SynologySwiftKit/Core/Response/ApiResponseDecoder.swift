import Foundation

// MARK: - ApiResponseDecoder

/// HTTP 响应解码器
/// HTTP response decoder
///
/// 验证 HTTP 状态码并将响应 Data 解码为目标类型。
/// Validates HTTP status code and decodes response Data into the target type.
struct ApiResponseDecoder {
    /// 解码 HTTP 响应
    /// Decode HTTP response
    ///
    /// - Parameters:
    ///   - type: 期望的解码类型 / Expected decode type
    ///   - data: 响应体数据 / Response body data
    ///   - response: URL 响应（用于检查 HTTP 状态码）/ URL response (for HTTP status validation)
    /// - Returns: 解码后的目标类型实例 / Decoded instance of target type
    /// - Throws:
    ///   - `SynologyError.network("Invalid response")` 如果 response 不是 HTTPURLResponse / if response is not HTTPURLResponse
    ///   - `SynologyError.network("Invalid HTTP status: \(code)")` 如果 HTTP 状态码非 2xx / if status code is not 2xx
    ///   - `SynologyError.network("Decoding failed: ...")` 如果 JSON 解码失败 / if JSON decoding fails
    func decode<Value: Decodable>(_ type: Value.Type, from data: Data, response: URLResponse) throws -> Value {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SynologyError.network(message: "Invalid response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw SynologyError.network(message: "Invalid HTTP status: \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoderProvider.shared.decode(Value.self, from: data)
        } catch {
            Logger.error("JSON decode error: \(error), data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw SynologyError.network(message: "Decoding failed: \(error.localizedDescription)")
        }
    }
}
