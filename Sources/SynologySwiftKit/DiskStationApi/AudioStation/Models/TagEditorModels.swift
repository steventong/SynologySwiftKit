//

//
//
//  Created by Steven on 2024/7/7.
//

import Foundation

// MARK: - TagEditorDocument

/// Tag 编辑器文档（读取结果）
/// Tag editor document (read result)
public struct TagEditorDocument: Sendable {
    /// 歌词（如果读取成功）/ Lyrics (if successfully read)
    public let lyrics: String?
    /// 读取成功的文件标签列表 / Successfully read file tag list
    public let files: [TagEditorData]
    /// 读取失败的文件数量 / Number of files that failed to read
    public let readFailedFileCount: Int

    public init(lyrics: String?, files: [TagEditorData], readFailedFileCount: Int) {
        self.lyrics = lyrics
        self.files = files
        self.readFailedFileCount = readFailedFileCount
    }
}

// MARK: - TagEditorArtwork

/// 封面图片引用
/// Artwork reference
public struct TagEditorArtwork: Equatable, Sendable {
    /// Audio Station 封面类型 / Audio Station artwork type
    public let type: String
    /// NAS 图片路径或远程图片 URL / NAS image path or remote image URL
    public let path: String

    public init(type: String, path: String) {
        self.type = type
        self.path = path
    }

    /// 保留文件中的原始封面
    /// Keep the original artwork embedded in the file
    public static let originalImage = TagEditorArtwork(type: "original_image", path: "")

    /// 使用歌曲目录或 NAS 其他目录中的图片作为封面
    /// Use an image from the song folder or another NAS folder as artwork
    /// - Parameter path: NAS 上的图片绝对路径 / Absolute image path on the NAS
    public static func imageFromFolder(path: String) -> TagEditorArtwork {
        TagEditorArtwork(type: "image_from_folder", path: path)
    }

    /// 使用远程 HTTP(S) 图片作为封面，由 Audio Station 下载图片
    /// Use a remote HTTP(S) image as artwork and let Audio Station download it
    /// - Parameter url: 远程图片 URL / Remote image URL
    public static func imageFromURL(url: URL) -> TagEditorArtwork {
        TagEditorArtwork(type: "image_from_URL", path: url.absoluteString)
    }
}

// MARK: - TagEditorUpdate

/// Tag 编辑更新请求模型
/// Tag editor update request model
public struct TagEditorUpdate: Sendable {
    /// 要更新的文件列表 / Files to update
    public let files: [TagEditorData]
    public let title: String
    public let artist: String
    public let album: String
    public let albumArtist: String
    public let composer: String
    public let genre: String
    public let comment: String
    public let lyrics: String
    public let track: Int?
    public let disc: Int?
    public let year: Int?
    /// 封面图片（可选）/ Artwork (optional)
    public let artwork: TagEditorArtwork?
    /// 字符编码（默认不转换）/ Character encoding (no conversion by default)
    public let codePage: String

    public init(
        files: [TagEditorData],
        title: String,
        artist: String,
        album: String,
        albumArtist: String,
        composer: String,
        genre: String,
        comment: String = "",
        lyrics: String = "",
        track: Int? = nil,
        disc: Int? = nil,
        year: Int? = nil,
        artwork: TagEditorArtwork? = nil,
        codePage: String = "SYNO_NO_CODE_PAGE_CONVERT"
    ) {
        self.files = files
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.composer = composer
        self.genre = genre
        self.comment = comment
        self.lyrics = lyrics
        self.track = track
        self.disc = disc
        self.year = year
        self.artwork = artwork
        self.codePage = codePage
    }
}

struct TagEditorResult: Decodable, Sendable {
    var success: Bool
    var readFailCount: Int
    var lyrics: String?
    var files: [TagEditorData]

    enum CodingKeys: String, CodingKey {
        case success
        case readFailCount = "read_fail_count"
        case lyrics
        case files
    }
}

struct TagEditorRequest: Codable, Sendable {
    var audioInfos: [TagEditorData]

    var lyrics: String
    var coverType: String
    var coverPath: String
    var title: String
    var artist: String
    var album: String
    var comment: String
    var genre: String
    var track: String
    var disc: String
    var year: String
    var albumArtist: String
    var composer: String
    var codePage: String

    enum CodingKeys: String, CodingKey {
        case audioInfos
        case lyrics
        case coverType
        case coverPath
        case title
        case artist
        case album
        case comment
        case genre
        case track
        case disc
        case year
        case albumArtist = "album_artist"
        case composer
        case codePage
    }

    init(update: TagEditorUpdate) {
        audioInfos = update.files
        lyrics = update.lyrics
        coverType = update.artwork?.type ?? ""
        coverPath = update.artwork?.path ?? ""
        title = update.title
        artist = update.artist
        album = update.album
        comment = update.comment
        genre = update.genre
        track = update.track.map(String.init) ?? ""
        disc = update.disc.map(String.init) ?? ""
        year = update.year.map(String.init) ?? ""
        albumArtist = update.albumArtist
        composer = update.composer
        codePage = update.codePage
    }
}

struct TagEditorFileReference: Encodable, Sendable {
    let path: String
}

// MARK: - TagEditorData

/// 单个文件的 Tag 数据
/// Tag data for a single file
public struct TagEditorData: Codable, Sendable {
    public var album: String
    public var albumArtist: String
    public var artist: String
    public var comment: String
    public var composer: String
    public var disc: Int

    enum CodingKeys: String, CodingKey {
        case album
        case albumArtist = "album_artist"
        case artist
        case comment
        case composer
        case disc
        case genre
        case path
        case title
        case track
        case year
    }
    public var genre: String
    public var path: String
    public var title: String
    public var track: Int
    public var year: Int

    public init(
        album: String, albumArtist: String, artist: String, comment: String, composer: String,
        disc: Int, genre: String, path: String, title: String, track: Int, year: Int
    ) {
        self.album = album
        self.albumArtist = albumArtist
        self.artist = artist
        self.comment = comment
        self.composer = composer
        self.disc = disc
        self.genre = genre
        self.path = path
        self.title = title
        self.track = track
        self.year = year
    }
}
