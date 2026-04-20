import XCTest
@testable import SynologySwiftKit

final class ApiInfoApiHappyPathTests: XCTestCase {
    func testRefreshFetchesAndPersistsCache() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        let apiInfoApi = ApiInfoApi(apiClient: apiClient, keyValueStorage: storage, cacheValidity: 60)

        apiClient.mockResponse = [
            SynologyApi.AudioStation.SONG.name: ApiInfoNode(path: "AudioStation/song.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil),
        ]

        try await apiInfoApi.refresh()
        let node = try await apiInfoApi.getApiInfoByApiName(apiName: SynologyApi.AudioStation.SONG.name)

        XCTAssertEqual(node.path, "AudioStation/song.cgi")

        let cached: [String: ApiInfoNode]? = storage.codable(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
        XCTAssertEqual(cached?[SynologyApi.AudioStation.SONG.name]?.maxVersion, 3)
        XCTAssertNotNil(storage.object(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName) as? Date)
    }

    func testLoadFromCacheOrRefreshUsesValidStoredCacheWithoutNetworkRequest() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        let apiInfoApi = ApiInfoApi(apiClient: apiClient, keyValueStorage: storage, cacheValidity: 60)

        let cachedNodes = [
            SynologyApi.AudioStation.PLAYLIST.name: ApiInfoNode(path: "AudioStation/playlist.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil),
        ]
        storage.set(cachedNodes, forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
        storage.set(Date(), forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)

        try await apiInfoApi.loadFromCacheOrRefresh()
        let node = try await apiInfoApi.getApiInfoByApiName(apiName: SynologyApi.AudioStation.PLAYLIST.name)

        XCTAssertEqual(node.path, "AudioStation/playlist.cgi")
        XCTAssertTrue(apiClient.requestedEndpoints.isEmpty)
    }
}
