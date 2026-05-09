import Foundation

struct ApiResponseDecoder {
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
