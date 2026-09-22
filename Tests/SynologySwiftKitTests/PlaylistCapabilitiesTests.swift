import Foundation
import XCTest
@testable import SynologySwiftKit

final class PlaylistCapabilitiesTests: XCTestCase {
    func testNormalAndSmartPlaylistEditingCapabilities() throws {
        let normal = try playlist(id: "playlist_personal_normal/123", type: "normal")
        XCTAssertEqual(normal.role, .regular)
        XCTAssertTrue(normal.capabilities.canAddSongs)
        XCTAssertTrue(normal.capabilities.canDelete)
        XCTAssertTrue(normal.capabilities.canRename)

        let smart = try playlist(id: "playlist_shared_smart/456", type: "smart")
        XCTAssertFalse(smart.capabilities.canAddSongs)
        XCTAssertTrue(smart.capabilities.canDelete)
        XCTAssertTrue(smart.capabilities.canRename)
    }

    func testSystemPlaylistIdentityDoesNotDependOnDisplayName() throws {
        let system = try playlist(id: "playlist_personal_normal/__SYNO_AUDIO_SHARED_SONGS__", name: "Localized title")
        XCTAssertEqual(system.role, .sharedSongs)
        XCTAssertFalse(system.capabilities.canAddSongs)
        XCTAssertFalse(system.capabilities.canDelete)
        XCTAssertFalse(system.capabilities.canRename)
    }

    func testUserPlaylistWithReservedLookingNameRemainsARegularPlaylist() throws {
        let user = try playlist(id: "playlist_personal_normal/user", name: "__SYNO_AUDIO_SHARED_SONGS__")
        XCTAssertEqual(user.role, .regular)
        XCTAssertTrue(user.capabilities.canAddSongs)
        XCTAssertTrue(user.capabilities.canRename)
    }

    private func playlist(id: String, name: String = "Playlist", type: String = "normal") throws -> Playlist {
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "name": name, "type": type,
                                                              "library": "personal", "sharing_status": "private"])
        return try JSONDecoder().decode(Playlist.self, from: data)
    }
}
