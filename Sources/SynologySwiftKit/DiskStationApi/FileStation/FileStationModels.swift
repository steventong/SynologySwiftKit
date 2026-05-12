//
//  FileStationModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/4.
//

import Foundation

// MARK: - FileDeletionTask

/// 文件删除任务引用（由 `SYNO.FileStation.Delete` 接口异步返回）
/// File deletion task reference (returned asynchronously by `SYNO.FileStation.Delete`)
public struct FileDeletionTask: Sendable {
    /// 删除任务 ID（用于轮询任务状态）
    /// Deletion task ID (used for polling task status)
    public let taskID: String

    public init(taskID: String) {
        self.taskID = taskID
    }
}

// MARK: - FileStationClient Internal Types

extension FileStationClient {
    /// 删除任务响应原始模型（内部使用）
    /// Raw delete task response model (internal use)
    struct DeleteTask: Decodable {
        /// 任务 ID / Task ID
        var taskid: String?
    }
}
