//
//  FileStationClient.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/4.
//

import Foundation

/// FileStation API 入口（依赖注入）
/// FileStation API entry (dependency injection)
public final class FileStationClient {
    /// API 客户端（internal 以便 extension 使用）
    /// API client (internal for extension access)
    let apiClient: ApiEndpointClient

    /// 初始化 FileStation API
    /// Initialize FileStation API
    /// - Parameter apiClient: API 客户端
    init(apiClient: ApiEndpointClient) {
        self.apiClient = apiClient
    }

    /// Authenticated original-file URL for streaming. Contains a session token; do not log or persist it.
    public func playbackURL(path: String) async throws -> URL {
        let paths = try ApiParameterValue.jsonEncoded([path])
        return try await apiClient.buildUrl(ApiEndpoint(
            api: ApiDefinition(name: "SYNO.FileStation.Download"),
            method: "download", version: 2, sidOnQuery: true, sidOnCookie: false
        ) {
            ("path", paths)
            ("mode", "open")
        })
    }

    /// Gets SYNO.FileStation.Info (v2), documented in the File Station API Guide.
    /// Requires File Station access; a permission failure alone does not indicate an invalid SID.
    /// Returns the API envelope without invalidating the session. An explicit SID excludes ambient cookies.
    public func info(sid: String? = nil) async throws -> DSMReadResponse {
        try await apiClient.requestEnvelope(ApiEndpoint(
            api: SynologyApi.FileStation.INFO, method: "get", version: 2,
            httpMethod: .get, sidOnQuery: sid == nil, sidOnCookie: false
        ) {
            if let sid { ("_sid", sid) }
        })
    }

    /// 删除文件
    /// Delete file
    /// - Parameter path: 文件路径
    /// - Returns: 删除任务信息
    public func delete(path: String) async throws -> FileDeletionTask {
        let delete: DeleteTask = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.FileStation.DELETE, method: "start", version: 2, httpMethod: .post) {
                ("accurate_progress", true)
                ("path", "[\"\(path)\"]")
            }
        )
        Logger.info("delete: \(path), result = \(delete)")
        guard let taskID = delete.taskid, !taskID.isEmpty else {
            throw SynologyError.api(code: -1, message: "delete task not started")
        }
        return FileDeletionTask(taskID: taskID)
    }
}
