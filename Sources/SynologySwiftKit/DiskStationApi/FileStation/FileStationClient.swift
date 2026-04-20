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
    let apiClient: ApiClientProviding

    /// 初始化 FileStation API
    /// Initialize FileStation API
    /// - Parameter apiClient: API 客户端
    init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /// 删除文件
    /// Delete file
    /// - Parameter path: 文件路径
    /// - Returns: 删除任务信息
    public func delete(path: String) async throws -> FileDeletionTask {
        let delete: DeleteTask = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.FileStation.DELETE, method: "start", version: 2, httpMethod: .post,
                        parameters: [
                            "accurate_progress": true,
                            "path": "[\"\(path)\"]",
                        ]))
        Logger.info("delete: \(path), result = \(delete)")
        guard let taskID = delete.taskid, !taskID.isEmpty else {
            throw SynologyError.api(code: -1, message: "delete task not started")
        }
        return FileDeletionTask(taskID: taskID)
    }
}
