//
//  QueryProgress.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/5/4.
//

import Foundation

// MARK: - QuerySongsProgress

/// 查询歌曲进度枚举
/// Query songs progress enum
public enum QuerySongsProgress: Sendable {
    /// 查询开始，返回总数和任务数
    /// Query started with total count and task count
    case started(total: Int, taskCount: Int)
    
    /// 批次查询完成
    /// Batch query completed
    case batchCompleted(songs: [Song], batchIndex: Int, batchCount: Int, total: Int)
    
    /// 批次查询失败
    /// Batch query failed
    case batchFailed(batchIndex: Int, error: String)
    
    /// 所有查询完成
    /// All queries completed
    case completed(totalSongs: Int)
    
    /// 查询失败
    /// Query failed
    case failed(error: QueryError)
}

// MARK: - QueryError

/// 查询错误
/// Query error
public enum QueryError: Error, Sendable {
    /// 获取总数失败
    /// Failed to get total count
    case fetchTotalFailed
    
    /// 歌曲列表为空
    /// Song list is empty
    case emptyList
    
    /// 查询错误
    /// Query error
    case queryError(message: String)
}
