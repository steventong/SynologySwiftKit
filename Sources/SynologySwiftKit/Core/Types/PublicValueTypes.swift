import Foundation

// MARK: - SynologyPage

/// 分页结果容器
/// Paged result container
///
/// Synology API 返回的分页数据统一使用此结构。
/// Used for all paginated Synology API responses.
public struct SynologyPage<Item: Sendable>: Sendable {
    /// 数据总条数（不受分页限制）
    /// Total number of items (regardless of pagination)
    public let total: Int

    /// 当前页的数据条目
    /// Items in the current page
    public let items: [Item]

    public init(total: Int, items: [Item]) {
        self.total = total
        self.items = items
    }
}

// MARK: - SynologySortDirection

/// 排序方向
/// Sort direction
public enum SynologySortDirection: String, Sendable {
    /// 升序
    /// Ascending order
    case ascending = "asc"

    /// 降序
    /// Descending order
    case descending = "desc"
}

// MARK: - SynologySortDescriptor

/// 排序描述符（字段 + 方向）
/// Sort descriptor (field + direction)
public struct SynologySortDescriptor: Sendable {
    /// 排序字段名
    /// Sort field name
    public let field: String

    /// 排序方向
    /// Sort direction
    public let direction: SynologySortDirection

    public init(field: String, direction: SynologySortDirection) {
        self.field = field
        self.direction = direction
    }
}

// MARK: - SynologyCredentials

/// Synology 登录凭据（服务器 + 账号 + 密码）
/// Synology login credentials (server + username + password)
public struct SynologyCredentials: Codable, Equatable, Sendable, SensitiveStorageValue {
    /// 服务器地址或 QuickConnect ID
    /// Server address or QuickConnect ID
    public let server: String

    /// 用户名
    /// Username
    public let username: String

    /// 密码
    /// Password
    public let password: String

    /// 是否启用 HTTPS
    /// Whether HTTPS is enabled
    public let usesHTTPS: Bool

    public init(server: String, username: String, password: String, usesHTTPS: Bool) {
        self.server = server
        self.username = username
        self.password = password
        self.usesHTTPS = usesHTTPS
    }
}

/// 持久化的 Synology Session 信息
/// Persisted Synology session info
public struct SynologySessionInfo: Codable, Equatable, Sendable, SensitiveStorageValue {
    public let sid: String
    public let did: String?

    public init(sid: String, did: String?) {
        self.sid = sid
        self.did = did
    }
}

/// 持久化的连接地址信息
/// Persisted connection info
public struct SynologyConnectionInfo: Codable, Equatable, Sendable, SensitiveStorageValue {
    public let url: String
    public let typeString: String

    public init(url: String, typeString: String) {
        self.url = url
        self.typeString = typeString
    }
}

/// 持久化的设备身份信息
/// Persisted device identity info
public struct SynologyDeviceInfo: Codable, Equatable, Sendable, SensitiveStorageValue {
    public let did: String
    public let name: String

    public init(did: String, name: String) {
        self.did = did
        self.name = name
    }
}

// MARK: - SynologyLibraryScope

/// 媒体库作用域
/// Media library scope
public enum SynologyLibraryScope: String, Sendable {
    /// 所有媒体库
    /// All libraries
    case all

    /// 仅共享媒体库
    /// Shared libraries only
    case shared

    /// 仅个人媒体库
    /// Personal libraries only
    case personal
}
