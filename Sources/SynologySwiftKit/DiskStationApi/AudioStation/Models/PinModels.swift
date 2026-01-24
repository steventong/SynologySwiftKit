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
public enum PinType: String, Codable {
    case folder
    case album
    case artist
    case composer
    case genre
}

// MARK: - Pin Error

/// Pin API 错误
/// Pin API Error
public enum PinApiError: Int, Error, LocalizedError {
    case unknown = 0
    case invalidParameter = 1001
    case operationFailed = 1002
    case alreadyPinned = 1006
    
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown error"
        case .invalidParameter:
            return "Invalid parameter"
        case .operationFailed:
            return "Operation failed"
        case .alreadyPinned:
            return "Item already pinned"
        }
    }
    
    /// 从错误码创建错误
    public static func from(code: Int) -> PinApiError {
        return PinApiError(rawValue: code) ?? .unknown
    }
}

// MARK: - Pin Criteria

/// 固定项筛选条件
/// Pin item criteria
public struct PinCriteria: Codable {
    public var folder: String?
    public var path: String?
    public var album: String?
    public var album_artist: String?
    public var artist: String?
    public var composer: String?
    public var genre: String?
    
    // MARK: Factory Methods
    
    /// 创建文件夹条件
    public static func folder(_ folderId: String) -> PinCriteria {
        PinCriteria(folder: folderId)
    }
    
    /// 创建专辑条件
    public static func album(_ album: String, albumArtist: String = "") -> PinCriteria {
        PinCriteria(album: album, album_artist: albumArtist)
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
        if let albumArtist = album_artist { result["album_artist"] = albumArtist }
        if let artist = artist { result["artist"] = artist }
        if let composer = composer { result["composer"] = composer }
        if let genre = genre { result["genre"] = genre }
        return result
    }
}

// MARK: - Pin Item

/// 固定项目
/// Pinned item
public struct PinItem: Codable {
    public let id: String?
    public let type: PinType
    public let name: String
    public let criteria: PinCriteria
}

// MARK: - API Results

struct PinListResult: Codable {
    let items: [PinItem]
    let offset: Int
    let total: Int
}

/// Pin 操作成功结果
struct PinOperationResult: Codable {
    let errors: [Int]
    let items: [PinItem]
}

/// Unpin 操作结果
public struct UnpinOperationResult: Codable {
    /// 失败的项目错误列表
    public let errors: [UnpinError]
    /// 成功取消固定的 ID 列表
    public let items: [String]
}

/// Unpin 错误项
public struct UnpinError: Codable {
    /// 错误码（1007 = 项目不存在）
    public let error: Int
    /// 失败的项目 ID
    public let id: String
}

