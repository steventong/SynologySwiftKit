import Foundation

/// HTTP request method used by SynologySwiftKit domain layer.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
