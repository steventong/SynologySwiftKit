//
//  SongApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/6/1.
//

import Foundation

// MARK: - SongApi

/// 歌曲查询 API 客户端
/// Song query API client
///
/// 封装 `SYNO.AudioStation.Song` 接口，支持列表查询、单曲信息获取和评分更新。
/// Wraps `SYNO.AudioStation.Song`; supports list query, single song info, and rating update.
public final class SongApi {
    private let apiClient: ApiRequestSending
    private let urlBuilder: ApiURLBuilding?

    init(apiClient: ApiRequestSending, urlBuilder: ApiURLBuilding? = nil) {
        self.apiClient = apiClient
        self.urlBuilder = urlBuilder ?? apiClient as? ApiURLBuilding
    }

    /// 分页查询歌曲，可按标签和最低评分筛选。
    ///
    /// POST SYNO.AudioStation.Song/list，声明版本 3。
    ///
    /// 排序字段原样发送，可用字段由服务端决定，例如 album、title、artist、random、song_rating。
    /// 歌曲模型未提供添加时间字段，不应直接套用专辑的 time 排序。
    ///
    /// - Parameters:
    ///   - limit: 每页数量，默认 100。
    ///   - offset: 起始偏移，默认 0。
    ///   - libraryScope: library，默认 shared。
    ///   - artist: 精确艺术家过滤；nil 时省略。
    ///   - album: 精确专辑过滤；nil 时省略。
    ///   - albumArtist: album_artist，精确专辑艺术家过滤。
    ///   - composer: 精确作曲家过滤。
    ///   - genre: 精确流派过滤。
    ///   - minimumRating: song_rating_meq，最低评分；原样发送，由服务端校验。
    ///   - includeFields: additional，默认 song_tag,song_audio,song_rating；nil 时省略。
    ///   - sort: sort_by/sort_direction；nil 时使用服务端顺序。
    /// - Returns: SynologyPage<Song>，来自 data.total/songs。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func list(
        limit: Int = 100, offset: Int = 0, libraryScope: SynologyLibraryScope = .shared,
        artist: String? = nil, album: String? = nil, albumArtist: String? = nil,
        composer: String? = nil, genre: String? = nil, minimumRating: Int? = nil,
        includeFields: String? = "song_tag,song_audio,song_rating",
        sort: SynologySortDescriptor? = nil
    ) async throws -> SynologyPage<Song> {
        let result: SongListResult = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post
            ) {
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
                ("artist", artist)
                ("album", album)
                ("album_artist", albumArtist)
                ("composer", composer)
                ("genre", genre)
                ("song_rating_meq", minimumRating)
                ("additional", includeFields)

                if let sort {
                    ("sort_by", sort.field)
                    ("sort_direction", sort.direction.rawValue)
                }
            }
        )
        return SynologyPage(total: result.total, items: result.songs)
    }

    /// 构造歌曲列表查询 URL。
    ///
    /// SYNO.AudioStation.Song/list，声明版本 3；所有参数放入 URL query。
    ///
    /// 固定请求 song_tag,song_audio,song_rating。只构造 URL，不执行歌曲请求；不要记录或长期保存包含 SID 的 URL。
    ///
    /// - Parameters:
    ///   - limit: 每页数量，必须指定。
    ///   - offset: 起始偏移，必须指定。
    ///   - libraryScope: library，默认 shared。
    /// - Returns: 带 _sid 的 URL；访问后返回歌曲列表 JSON，不是音频。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func listURL(limit: Int, offset: Int, libraryScope: SynologyLibraryScope = .shared) async throws -> URL {
        guard let urlBuilder else {
            throw SynologyError.network(message: "URL builder not configured")
        }

        return try await urlBuilder.buildUrl(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "list", version: 3, httpMethod: .post,
                sidOnQuery: true
            ) {
                ("additional", "song_tag,song_audio,song_rating")
                ("library", libraryScope.rawValue)
                ("limit", limit)
                ("offset", offset)
            }
        )
    }

    /// 读取单首歌曲。
    ///
    /// GET SYNO.AudioStation.Song/getinfo，声明版本 2。
    ///
    /// 不传 library。
    ///
    /// - Parameters:
    ///   - id: 服务端歌曲 ID，不是文件路径。
    /// - Returns: data.songs 的第一项，固定展开标签、音频和评分。
    /// - Throws: 底层请求错误；songs 为空时抛出 SynologyError.api(code: -1)。
    public func getInfo(id: String) async throws -> Song {
        let result: SongInfo = try await apiClient.request(
            ApiEndpoint(
                api: SynologyApi.AudioStation.SONG, method: "getinfo", version: 2
            ) {
                ("id", id)
                ("additional", "song_tag,song_audio,song_rating")
            }
        )
        guard let song = result.songs.first else {
            throw SynologyError.api(code: -1, message: "query song failed")
        }

        return song
    }

    /// 设置歌曲评分或清除评分。
    ///
    /// POST SYNO.AudioStation.Song/setrating，声明版本 2。
    ///
    /// - Parameters:
    ///   - id: 歌曲 ID。
    ///   - rating: 0–5；0 清除评分，1–5 表示星级。Kit 原样发送，不做范围校验。
    /// - Returns: SongRatingUpdate，包含此次请求的 songID/rating；不是重新读取的歌曲。
    /// - Throws: 连接、请求和响应解码失败时抛出底层错误；服务端拒绝时抛出 SynologyError。
    public func setRating(id: String, rating: Int) async throws -> SongRatingUpdate {
        let api = ApiEndpoint(
            api: SynologyApi.AudioStation.SONG, method: "setrating", version: 2,
            httpMethod: .post) {
                ("id", id)
                ("rating", rating)
            }

        let _: EmptyData = try await apiClient.request(api)
        return SongRatingUpdate(songID: id, rating: rating)
    }
}
