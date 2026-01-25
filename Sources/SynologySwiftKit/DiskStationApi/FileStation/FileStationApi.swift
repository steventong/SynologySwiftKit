//
//  FileStationApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/4.
//

import Foundation

/// FileStation API 入口（依赖注入）
/// FileStation API entry (dependency injection)
public class FileStationApi {
    /// API 客户端（internal 以便 extension 使用）
    /// API client (internal for extension access)
    let apiClient: ApiClientProviding

    /// 初始化 FileStation API
    /// Initialize FileStation API
    /// - Parameter apiClient: API 客户端
    public init(apiClient: ApiClientProviding) {
        self.apiClient = apiClient
    }

    /// 删除文件
    /// Delete file
    /// - Parameter path: 文件路径
    /// - Returns: 是否成功启动删除任务
    public func delete(path: String) async throws -> Bool {
        let delete: DeleteTask = try await apiClient.request(
            ApiEndpoint(api: SynologyApi.FileStation.DELETE, method: "start", version: 2, httpMethod: .post,
                        parameters: [
                            "accurate_progress": true,
                            "path": "[\"\(path)\"]",
                        ]),
            resultType: DeleteTask.self
        )
        Logger.info("delete: \(path), result = \(delete)")
        return delete.taskid != nil
    }
}
