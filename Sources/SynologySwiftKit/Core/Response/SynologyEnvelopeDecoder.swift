import Foundation

struct SynologyEnvelopeDecoder {
    func unwrap<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) throws -> Value {
        try response.unwrap()
    }

    func isSuccessful<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) -> Bool {
        response.success
    }

    func errorCode<Value: Decodable & Sendable>(_ response: SynologyResponse<Value>) -> Int? {
        response.error?.code
    }
}
