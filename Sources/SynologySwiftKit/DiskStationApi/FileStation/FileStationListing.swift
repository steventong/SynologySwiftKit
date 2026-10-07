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
    public func listShares() async throws -> FileStationShares {
        try await apiClient.request(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.List"), method: "list_share", version: 2
        ) {
            ("limit", 0)
            ("sort_by", "name")
        })
    }

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
