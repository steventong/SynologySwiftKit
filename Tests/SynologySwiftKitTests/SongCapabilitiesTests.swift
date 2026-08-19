import XCTest
@testable import SynologySwiftKit

final class SongCapabilitiesTests: XCTestCase {
    func testSupportedLocalFormatsExposeAllEditingCapabilities() {
        let supportedExtensions = [
            "mp3", "ogg", "m4a", "m4p", "flac", "aiff", "aif", "m4b",
        ]

        for fileExtension in supportedExtensions {
            let song = makeSong(
                id: "music_1",
                path: "/music/Track.\(fileExtension.uppercased())"
            )

            XCTAssertEqual(song.capabilities, .allSupported, fileExtension)
        }
    }

    func testUnsupportedFormatsDisableAllEditingCapabilities() {
        for fileExtension in ["ape", "wav", "wma", "dsf"] {
            let song = makeSong(id: "music_1", path: "/music/Track.\(fileExtension)")

            assertEditingDisabled(song.capabilities, context: fileExtension)
        }
    }

    func testVirtualSongsDisableEditingEvenForSupportedFormats() {
        for id in ["music_v_1", "music_p_v_1"] {
            let song = makeSong(id: id, path: "/music/CDImage.flac")

            assertEditingDisabled(song.capabilities, context: id)
        }
    }

    func testRemoteResourcesDisableEditing() {
        let song = makeSong(
            id: "music_1",
            type: "remote",
            path: "https://example.com/Track.mp3"
        )

        assertEditingDisabled(song.capabilities, context: "remote")
    }

    func testFolderSongEntriesUseTheSameCapabilityRules() {
        let editable = Folder(
            id: "music_1",
            path: "/music/Track.flac",
            isPersonal: false,
            title: "Track",
            type: "file",
            additional: nil
        )
        let virtual = Folder(
            id: "music_v_1",
            path: "/music/CDImage.flac",
            isPersonal: false,
            title: "Track",
            type: "file",
            additional: nil
        )

        XCTAssertEqual(editable.capabilities, .allSupported)
        assertEditingDisabled(virtual.capabilities, context: "folder virtual track")
    }

    private func makeSong(
        id: String,
        type: String = "file",
        path: String
    ) -> Song {
        Song(
            id: id,
            title: "Track",
            type: type,
            path: path,
            additional: nil
        )
    }

    private func assertEditingDisabled(
        _ capabilities: SongCapabilities,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(capabilities.supportsMetadataEditing, context, file: file, line: line)
        XCTAssertFalse(capabilities.supportsLyricsEditing, context, file: file, line: line)
        XCTAssertFalse(capabilities.supportsArtworkEditing, context, file: file, line: line)
    }
}
