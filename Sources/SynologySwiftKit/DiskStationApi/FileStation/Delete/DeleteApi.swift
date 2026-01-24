//
//  DeleteApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/3.
//

import Foundation

extension FileStationApi {

    /// 删除文件
    /// Delete file
    /// - Parameter path: 文件路径
    /// - Returns: 是否成功启动删除任务
    public func delete(path: String) async throws -> Bool {
        let delete: DeleteTask = try await apiClient.requestForData(
            ApiEndpoint(
                api: SynologyApi.FileStation.DELETE, method: "start", version: 2, httpMethod: .post,
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
