//
//  PinApi+Models.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

// MARK: - Pin Type

/// 固定项类型
/// Pin item type
public enum PinType: String, Codable, Sendable {
    case folder
    case album
    case artist
    case composer
    case genre
}

// MARK: - Pin Criteria

/// 固定项筛选条件
/// Pin item criteria
public struct PinCriteria: Codable, Sendable {
    public var folder: String?
    public var path: String?
    public var album: String?
    public var albumArtist: String?
    public var artist: String?
    public var composer: String?
    public var genre: String?

    enum CodingKeys: String, CodingKey {
        case folder
        case path
        case album
        case albumArtist = "album_artist"
        case artist
        case composer
        case genre
    }

    // MARK: Factory Methods

    /// 创建文件夹条件
    public static func folder(_ folderId: String) -> PinCriteria {
        PinCriteria(folder: folderId)
    }

    /// 创建专辑条件
    public static func album(_ album: String, albumArtist: String = "") -> PinCriteria {
        PinCriteria(album: album, albumArtist: albumArtist)
    }

    /// 创建艺术家条件
    public static func artist(_ artist: String) -> PinCriteria {
        PinCriteria(artist: artist)
    }

    /// 创建作曲家条件
    public static func composer(_ composer: String) -> PinCriteria {
        PinCriteria(composer: composer)
    }

    /// 创建流派条件
    public static func genre(_ genre: String) -> PinCriteria {
        PinCriteria(genre: genre)
    }

    // MARK: Internal

    /// 转换为字典（用于 API 请求）
    func toDictionary() -> [String: String] {
        var result: [String: String] = [:]
        if let folder = folder { result["folder"] = folder }
        if let album = album { result["album"] = album }
        if let albumArtist = albumArtist { result["album_artist"] = albumArtist }
        if let artist = artist { result["artist"] = artist }
        if let composer = composer { result["composer"] = composer }
        if let genre = genre { result["genre"] = genre }
        return result
    }
}

// MARK: - Pin Item

/// 固定项目
/// Pinned item
public struct PinItem: Codable, Sendable {
    public let id: String
    public let type: PinType
    public let name: String
    public let criteria: PinCriteria
}

// MARK: - API Results

public typealias PinListResult = SynologyListResult<PinItem>

extension SynologyListResult where T == PinItem {
    private enum ListCodingKeys: String, CodingKey {
        case offset
        case total
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ListCodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([PinItem].self, forKey: .items)
    }
}


/// Pin 操作成功结果
struct PinOperationResult: Codable, Sendable {
    let errors: [Int]
    let items: [PinItem]
}

/// Unpin 操作结果
public struct UnpinOperationResult: Codable, Sendable {
    /// 失败的项目错误列表
    public let errors: [UnpinError]
    /// 成功取消固定的 ID 列表
    public let items: [String]
}

/// Unpin 错误项
public struct UnpinError: Codable, Sendable {
    /// 错误码（1007 = 项目不存在）
    public let error: Int
    /// 失败的项目 ID
    public let id: String
}
