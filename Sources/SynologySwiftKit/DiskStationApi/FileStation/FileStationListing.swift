import Foundation

public struct FileStationEntry: Decodable, Identifiable, Sendable {
    public let name: String
    public let path: String
    public let isdir: Bool
    public let additional: Additional?
    public var id: String { path }

    public struct Additional: Decodable, Sendable {
        public let size: Int64?
        public let time: FileTime?
    }
    public struct FileTime: Decodable, Sendable {
        public let mtime: TimeInterval?
    }
}

public struct FileStationPage: Decodable, Sendable {
    public let total: Int
    public let offset: Int
    public let files: [FileStationEntry]
}

public struct FileStationShares: Decodable, Sendable {
    public let total: Int
    public let offset: Int
    public let shares: [FileStationEntry]
}

extension FileStationClient {
    /// 列出当前账号可见的共享目录。
    ///
    /// GET SYNO.FileStation.List/list_share v2，limit=0、sort_by=name。
    /// - Returns: FileStationShares，包含 total、offset 和 shares。
    /// - Throws: 请求或响应解码错误。
    public func listShares() async throws -> FileStationShares {
        try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.List"), method: "list_share", version: 2
        ) {
            ("limit", 0)
            ("sort_by", "name")
        })
    }

    /// 分页列出目录内容。
    ///
    /// GET SYNO.FileStation.List/list v2，按 name/asc 排序，additional 为 JSON 数组 size/time。
    /// - Parameters:
    ///   - folderPath: NAS 目录路径，发送为 folder_path。
    ///   - offset: 起始偏移，默认 0；负值改为 0。
    ///   - limit: 每页数量，默认 200；小于 1 时改为 1。
    /// - Returns: FileStationPage，包含 total、offset 和 files。
    /// - Throws: 请求或响应解码错误。
    public func list(folderPath: String, offset: Int = 0, limit: Int = 200) async throws -> FileStationPage {
        try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.List"), method: "list", version: 2
        ) {
            ("folder_path", folderPath)
            ("offset", max(0, offset))
            ("limit", max(1, limit))
            ("sort_by", "name")
            ("sort_direction", "asc")
            ("additional", "[\"size\",\"time\"]")
        })
    }
}
