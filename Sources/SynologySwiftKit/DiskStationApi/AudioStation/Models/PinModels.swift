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

/// 固定操作结果。
///
/// 重复固定表示目标状态已经满足，是正常的幂等结果而不是错误。
public enum PinCreationResult: Sendable {
    case created(PinItem)
    case alreadyExists

    public var item: PinItem? {
        guard case let .created(item) = self else {
            return nil
        }
        return item
    }
}

public struct PinRemovalResult: Sendable {
    public let removedIDs: [String]
    public let failures: [UnpinError]

    public init(removedIDs: [String], failures: [UnpinError]) {
        self.removedIDs = removedIDs
        self.failures = failures
    }

    public var removedAll: Bool {
        failures.isEmpty
    }
}

// MARK: - API Results

struct PinListResult: Decodable, Sendable {
    public let offset: Int
    public let total: Int
    public let items: [PinItem]

    enum CodingKeys: String, CodingKey {
        case offset
        case total
        case items
    }
}


/// Pin 操作成功结果
struct PinOperationResult: Codable, Sendable {
    let errors: [Int]
    let items: [PinItem]
}

struct PinRequestItem: Encodable, Sendable {
    let type: PinType
    let criteria: PinCriteria
    let name: String
}

/// Unpin 操作结果
struct UnpinOperationResult: Codable, Sendable {
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
