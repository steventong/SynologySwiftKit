import XCTest
@testable import SynologySwiftKit

final class StorageAndModelTests: XCTestCase {
    func testUserDefaultsStorageStoresPrimitiveAndCodableValues() {
        let suiteName = "StorageAndModelTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let storage = UserDefaultsStorage(userDefaults: suite)
        defer { suite.removePersistentDomain(forName: suiteName) }

        storage.setString("value", forKey: "string")
        storage.setInteger(4, forKey: "int")
        storage.setBool(true, forKey: "bool")
        storage.setDate(Date(timeIntervalSince1970: 20), forKey: "date")
        storage.setCodable(makeAudioStationInfo(version: 555), forKey: "info")

        XCTAssertEqual(storage.string(forKey: "string"), "value")
        XCTAssertEqual(storage.integer(forKey: "int"), 4)
        XCTAssertEqual(storage.bool(forKey: "bool"), true)
        XCTAssertNotNil(storage.date(forKey: "date"))
        let info: AudioStationInfo? = storage.codable(forKey: "info")
        XCTAssertEqual(info?.version, 555)

        storage.removeObject(forKey: "string")
        XCTAssertNil(storage.string(forKey: "string"))
    }

    func testSongAndPlaylistModelComputedProperties() {
        let song = makeSong()
        XCTAssertEqual(song.audio?.bitrate, 320000)
        XCTAssertEqual(song.rating?.rating, 5)
        XCTAssertEqual(song.tag?.album, "Album")
        XCTAssertEqual(SongStreamQuality.HIGH.format, "mp3")
        XCTAssertEqual(SongStreamQuality.MEDIUM.bitrate, 192000)
        XCTAssertNil(SongStreamQuality.ORIGINAL.bitrate)

        let playlist = makePlaylist(song: song)
        XCTAssertEqual(playlist.songs.count, 1)
        XCTAssertEqual(playlist.songsOffset, 0)
        XCTAssertEqual(playlist.songsTotal, 1)
    }

    func testSongAndPlaylistModelFallbackValuesWithoutAdditional() {
        let song = Song(id: "music_2", title: "Bare", type: "file", path: "/music/Bare.mp3", additional: nil)
        let playlist = Playlist(id: "playlist_2", library: "shared", name: "Empty", sharingStatus: "private", type: "normal", additional: nil)

        XCTAssertNil(song.audio)
        XCTAssertNil(song.rating)
        XCTAssertNil(song.tag)
        XCTAssertTrue(playlist.songs.isEmpty)
        XCTAssertEqual(playlist.songsOffset, 0)
        XCTAssertEqual(playlist.songsTotal, 0)
    }
}
