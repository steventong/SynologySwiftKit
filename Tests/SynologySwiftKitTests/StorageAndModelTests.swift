import XCTest
@testable import SynologySwiftKit

final class StorageAndModelTests: XCTestCase {
    func testUserDefaultsStorageStoresPrimitiveAndCodableValues() {
        let suiteName = "StorageAndModelTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let storage = UserDefaultsStorage(userDefaults: suite)
        defer { suite.removePersistentDomain(forName: suiteName) }

        storage.set("value", forKey: "string")
        storage.set(4, forKey: "int")
        storage.set(true, forKey: "bool")
        storage.set(Date(timeIntervalSince1970: 20), forKey: "date")
        storage.set(makeAudioStationInfo(version: 555), forKey: "info")

        XCTAssertEqual(storage.string(forKey: "string"), "value")
        XCTAssertEqual(storage.integer(forKey: "int"), 4)
        XCTAssertEqual(storage.bool(forKey: "bool"), true)
        XCTAssertNotNil(storage.object(forKey: "date") as? Date)
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
        XCTAssertEqual(SongStreamQuality.MEDIUM.bitrate, 256000)
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
