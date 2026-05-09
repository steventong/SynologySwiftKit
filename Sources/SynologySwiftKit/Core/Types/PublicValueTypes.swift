import Foundation

public struct SynologyPage<Item: Sendable>: Sendable {
    public let total: Int
    public let items: [Item]

    public init(total: Int, items: [Item]) {
        self.total = total
        self.items = items
    }
}

public enum SynologySortDirection: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

public struct SynologySortDescriptor: Sendable {
    public let field: String
    public let direction: SynologySortDirection

    public init(field: String, direction: SynologySortDirection) {
        self.field = field
        self.direction = direction
    }
}

public struct SynologyCredentials: Sendable {
    public let server: String
    public let username: String
    public let password: String
    public let usesHTTPS: Bool

    public init(server: String, username: String, password: String, usesHTTPS: Bool) {
        self.server = server
        self.username = username
        self.password = password
        self.usesHTTPS = usesHTTPS
    }
}

public enum SynologyLibraryScope: String, Sendable {
    case all
    case shared
    case personal
}
