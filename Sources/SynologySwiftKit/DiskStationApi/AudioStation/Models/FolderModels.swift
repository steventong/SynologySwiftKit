//
//  FolderModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - Folder

/// 文件夹/条目数据模型（AudioStation 文件夹浏览）
/// Folder/item data model (AudioStation folder browse)
public struct Folder: Decodable, Sendable {
    /// 条目 ID / Item ID
    public var id: String
    /// 文件路径 / File path
    public var path: String
    /// 是否为个人媒体库 / Whether it is a personal library
    public var isPersonal: Bool?
    /// 显示标题 / Display title
    public var title: String
    /// 条目类型（"folder" 或 "file"）/ Item type ("folder" or "file")
    public var type: String
    /// 额外信息（歌曲标签/音频信息等）/ Additional info (song tag/audio info, etc.)
    public var additional: SongAdditional?

    /// 文件浏览中的歌曲条目沿用与歌曲列表相同的 Audio Station 能力规则。
    public var capabilities: SongCapabilities {
        AudioStationSongCapabilitiesResolver.resolve(
            id: id,
            type: type,
            path: path
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case isPersonal = "is_personal"
        case title
        case type
        case additional
    }
}

// MARK: - FolderListResult (Internal)

/// 文件夹列表接口响应（内部使用）
/// Folder list API response (internal use)
struct FolderListResult: Decodable, Sendable {
    /// 当前文件夹 ID / Current folder ID
    public let id: String
    /// 子条目列表 / Child item list
    public let items: [Folder]
    /// 当前偏移量 / Current offset
    public let offset: Int
    /// 总条目数 / Total item count
    public let total: Int
    /// 总文件夹数 / Total folder count
    public let folderTotal: Int

    enum CodingKeys: String, CodingKey {
        case id
        case items
        case offset
        case total
        case folderTotal = "folder_total"
    }
}
