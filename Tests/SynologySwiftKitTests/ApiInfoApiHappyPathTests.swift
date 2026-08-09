import XCTest
@testable import SynologySwiftKit

final class ApiInfoApiHappyPathTests: XCTestCase {
    func testRefreshFetchesAndPersistsCache() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        let apiInfoApi = ApiInfoApi(apiClient: apiClient, keyValueStorage: storage, cacheValidity: 60)

        apiClient.mockResponse = [
            SynologyApi.Core.INFO.name: ApiInfoNode(path: "query.cgi", minVersion: 1, maxVersion: 1, requestFormat: nil),
            SynologyApi.AudioStation.SONG.name: ApiInfoNode(path: "AudioStation/song.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil),
        ]

        try await apiInfoApi.refresh()
        let infoNode = try await apiInfoApi.getApiInfoByApiName(apiName: SynologyApi.Core.INFO.name)
        let node = try await apiInfoApi.getApiInfoByApiName(apiName: SynologyApi.AudioStation.SONG.name)

        XCTAssertEqual(infoNode.path, "query.cgi")
        XCTAssertEqual(node.path, "AudioStation/song.cgi")

        let requestedEndpoint = try XCTUnwrap(apiClient.requestedEndpoints.first)
        XCTAssertEqual(apiClient.requestedEndpoints.count, 1)
        XCTAssertEqual(requestedEndpoint.fullPath, "/webapi/query.cgi")
        XCTAssertEqual(requestedEndpoint.httpMethod, .get)
        XCTAssertEqual(requestedEndpoint.parameters["api"]?.stringValue, SynologyApi.Core.INFO.name)
        XCTAssertEqual(requestedEndpoint.parameters["version"]?.stringValue, "1")
        XCTAssertEqual(requestedEndpoint.parameters["method"]?.stringValue, "query")
        XCTAssertEqual(requestedEndpoint.parameters["query"]?.stringValue, "all")

        let cached: [String: ApiInfoNode]? = storage.codable(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
        XCTAssertEqual(cached?[SynologyApi.Core.INFO.name]?.path, "query.cgi")
        XCTAssertEqual(cached?[SynologyApi.AudioStation.SONG.name]?.maxVersion, 3)
        XCTAssertNotNil(storage.date(forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName))
    }

    func testLoadFromCacheOrRefreshUsesValidStoredCacheWithoutNetworkRequest() async throws {
        let apiClient = MockApiClient()
        let storage = MockKeyValueStorage()
        let apiInfoApi = ApiInfoApi(apiClient: apiClient, keyValueStorage: storage, cacheValidity: 60)

        let cachedNodes = [
            SynologyApi.AudioStation.PLAYLIST.name: ApiInfoNode(path: "AudioStation/playlist.cgi", minVersion: 1, maxVersion: 3, requestFormat: nil),
        ]
        storage.setCodable(cachedNodes, forKey: KeyValueStorageKeys.DISK_STATION_API_INFO.keyName)
        storage.setDate(Date(), forKey: KeyValueStorageKeys.DISK_STATION_API_INFO_UPDATE_TIME.keyName)

        try await apiInfoApi.loadFromCacheOrRefresh()
        let node = try await apiInfoApi.getApiInfoByApiName(apiName: SynologyApi.AudioStation.PLAYLIST.name)

        XCTAssertEqual(node.path, "AudioStation/playlist.cgi")
        XCTAssertTrue(apiClient.requestedEndpoints.isEmpty)
    }
}
