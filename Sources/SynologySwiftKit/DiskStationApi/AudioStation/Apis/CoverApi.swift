//
//  CoverApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/15.
//

import Foundation

// MARK: - CoverApi

/// 封面 URL 构建 API
/// Cover URL builder API
///
/// 封装 `SYNO.AudioStation.Cover` 接口，返回不同类型封面的直接访问 URL。
/// Wraps `SYNO.AudioStation.Cover`; returns direct-access URLs for various cover types.
public final class CoverApi {
    private let urlBuilder: ApiURLBuilding

    init(urlBuilder: ApiURLBuilding) {
        self.urlBuilder = urlBuilder
    }

    /// 构造封面图片 URL。
    ///
    /// SYNO.AudioStation.Cover/getsongcover，声明版本 1。
    ///
    /// 只生成 URL，不下载图片；未设置 output_default/is_hr/view，不承诺无封面时一定返回默认图。不要记录或长期保存此 URL。
    ///
    /// - Parameters:
    ///   - songID: 歌曲 ID。
    ///   - libraryScope: library，默认 all。
    /// - Returns: 带 _sid 的 URL，访问后返回图片二进制。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func songCoverURL(songID: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getsongcover", version: 1) {
            ("library", libraryScope.rawValue)
            ("id", songID)
        }
        )
    }

    /// 构造封面图片 URL。
    ///
    /// SYNO.AudioStation.Cover/getcover，声明版本 3。
    ///
    /// 只生成 URL，不下载图片；未设置 output_default/is_hr/view，不承诺无封面时一定返回默认图。不要记录或长期保存此 URL。
    ///
    /// - Parameters:
    ///   - albumName: album_name，专辑名称。
    ///   - albumArtistName: album_artist_name，专辑艺术家名称。
    ///   - libraryScope: library，默认 all。
    /// - Returns: 带 _sid 的 URL，访问后返回图片二进制。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func albumCoverURL(albumName: String, albumArtistName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("album_name", albumName)
            ("album_artist_name", albumArtistName)
        }
        )
    }

    /// 构造封面图片 URL。
    ///
    /// SYNO.AudioStation.Cover/getcover，声明版本 3。
    ///
    /// 只生成 URL，不下载图片；未设置 output_default/is_hr/view，不承诺无封面时一定返回默认图。不要记录或长期保存此 URL。
    ///
    /// - Parameters:
    ///   - artistName: artist_name，艺术家名称。
    ///   - libraryScope: library，默认 all。
    /// - Returns: 带 _sid 的 URL，访问后返回图片二进制。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func artistCoverURL(artistName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("artist_name", artistName)
        }
        )
    }

    /// 构造封面图片 URL。
    ///
    /// SYNO.AudioStation.Cover/getcover，声明版本 3。
    ///
    /// 只生成 URL，不下载图片；未设置 output_default/is_hr/view，不承诺无封面时一定返回默认图。不要记录或长期保存此 URL。
    ///
    /// - Parameters:
    ///   - composerName: composer_name，作曲家名称。
    ///   - libraryScope: library，默认 all。
    /// - Returns: 带 _sid 的 URL，访问后返回图片二进制。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func composerCoverURL(composerName: String, libraryScope: SynologyLibraryScope = .all) async throws -> URL {
        return try await urlBuilder.buildUrl(ApiEndpoint(api: SynologyApi.AudioStation.COVER, method: "getcover", version: 3) {
            ("library", libraryScope.rawValue)
            ("composer_name", composerName)
        }
        )
    }
}
