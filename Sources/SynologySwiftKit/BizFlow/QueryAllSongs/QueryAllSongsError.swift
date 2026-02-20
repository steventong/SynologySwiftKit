//
//  QueryAllSongsError.swift
//  SynologySwiftKit
//
//  Created by Steven on 20/02/2026.
//

// MARK: - QueryAllSongsError

/// 查询错误
/// Query error
public enum QueryAllSongsError: Error, Sendable {
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
