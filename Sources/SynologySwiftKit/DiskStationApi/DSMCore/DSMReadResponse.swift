import Foundation

/// Response from DSM core read APIs. API rejection is returned unchanged;
/// transport, discovery and decoding failures are thrown by the request pipeline.
public struct DSMReadResponse: Codable, Sendable {
    public let success: Bool
    public let data: [String: DSMJSONValue]?
    public let error: APIError?

    public struct APIError: Codable, Sendable {
        public let code: Int
        public let errors: DSMJSONValue?
    }
}

/// Preserves DSM fields without assuming a fixed schema across DSM versions.
public enum DSMJSONValue: Codable, Sendable, Equatable {
    case string(String), number(Double), bool(Bool)
    case object([String: DSMJSONValue]), array([DSMJSONValue]), null

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode([String: DSMJSONValue].self) { self = .object(v) }
        else { self = .array(try value.decode([DSMJSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
}
