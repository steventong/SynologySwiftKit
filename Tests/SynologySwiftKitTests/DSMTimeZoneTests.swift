import XCTest
@testable import SynologySwiftKit

final class DSMTimeZoneTests: XCTestCase {
    func testReadsNumericSettingsAndNASZoneListThroughDiscovery() async throws {
        let transport = MockApiClient()
        var methods: [String] = []
        transport.requestHandler = { endpoint in
            XCTAssertEqual(endpoint.apiName, "SYNO.Core.Region.NTP")
            XCTAssertEqual(endpoint.version, 1)
            XCTAssertEqual(endpoint.httpMethod, .post)
            methods.append(endpoint.method)
            if endpoint.method == "get" { return try self.settings() }
            XCTAssertEqual(endpoint.method, "listzone")
            return try self.list(key: "vendor-future-zone", offset: 28800)
        }
        let info = try await DSMInfoClient(apiClient: transport).timeZoneInfo()
        XCTAssertEqual(methods, ["get", "listzone"])
        XCTAssertEqual(info.displayPrefix, "GMT+08:00")
        XCTAssertEqual(info.currentTimeZone.secondsFromGMT(), 28800)
    }

    func testAnyNASKeyWorksWithoutNameRecognition() throws {
        for key in ["Beijing", "Pacific", "CST", "地区名称", "vendor-future-zone", "12345"] {
            let settings = try settings(key: key)
            let info = try settings.resolvedTimeZone(from: list(key: key, offset: 28800))
            XCTAssertEqual(info.displayPrefix, "GMT+08:00", key)
        }
    }

    func testNumericPrefixesCoverFractionalHoursAndDateLineExtremes() throws {
        let cases = [(-43200, "GMT-12:00"), (-12600, "GMT-03:30"), (-9000, "GMT-02:30"), (0, "GMT+00:00"),
                     (16200, "GMT+04:30"), (20700, "GMT+05:45"), (28800, "GMT+08:00"),
                     (34200, "GMT+09:30"), (45900, "GMT+12:45"), (50400, "GMT+14:00")]
        for (offset, expected) in cases {
            let settings = try settings(currentOffset: offset)
            let info = try settings.resolvedTimeZone(from: list(offset: offset))
            XCTAssertEqual(info.displayPrefix, expected)
            XCTAssertEqual(info.currentTimeZone.secondsFromGMT(), offset)
        }
    }

    func testDSTCalendarOffsetDoesNotChangeConfiguredDropdownPrefix() throws {
        // The NAS's local midnight is already the following day at UTC-4,
        // while its dropdown still labels the standard offset GMT-05:00.
        let info = try settings(currentOffset: -14400).resolvedTimeZone(from: list(offset: -18000))
        XCTAssertEqual(info.displayPrefix, "GMT-05:00")
        XCTAssertEqual(info.currentTimeZone.secondsFromGMT(), -14400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = info.currentTimeZone
        let now = ISO8601DateFormatter().date(from: "2026-07-16T04:30:00Z")!
        XCTAssertEqual(calendar.component(.day, from: now), 16)
    }

    func testInvalidOrMismatchedServerDataDoesNotGuess() throws {
        let settings = try settings()
        for list in [try self.list(key: "other"), try self.list(offset: 100000), try self.list(offset: 61),
                     DSMTimeZoneList(zonedata: []),
                     DSMTimeZoneList(zonedata: [.init(value: "vendor-future-zone", offset: 0),
                                               .init(value: "vendor-future-zone", offset: 3600)])] {
            XCTAssertThrowsError(try settings.resolvedTimeZone(from: list))
        }
        for change: [String: Any] in [["date": "2026/2/30"], ["hour": 24], ["minute": -1],
                                      ["second": 60], ["timestamp": 0], ["timezone": ""]] {
            XCTAssertThrowsError(try self.settings(changes: change).resolvedTimeZone(from: list()))
        }
    }

    func testMissingClockFieldsAndZoneOffsetsFailDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode(DSMTimeSettings.self, from: Data(#"{"timezone":"Beijing"}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(DSMTimeZoneList.self, from: Data(#"{"zonedata":[{"value":"Beijing"}]}"#.utf8)))
    }

    func testPermissionFailureIsPropagatedForEitherRead() async throws {
        for deniedMethod in ["get", "listzone"] {
            let transport = MockApiClient()
            transport.requestHandler = { endpoint in
                if endpoint.method == deniedMethod { throw SynologyError.api(code: 105, message: "Denied") }
                return try self.settings()
            }
            do {
                _ = try await DSMInfoClient(apiClient: transport).timeZoneInfo()
                XCTFail("Expected a permission error")
            } catch let SynologyError.api(code, _) { XCTAssertEqual(code, 105) }
        }
    }

    private func settings(key: String = "vendor-future-zone", currentOffset: Int = 28800,
                          changes: [String: Any] = [:]) throws -> DSMTimeSettings {
        let localAsUTC = ISO8601DateFormatter().date(from: "2026-07-16T00:30:00Z")!.timeIntervalSince1970
        var payload: [String: Any] = ["timezone": key, "date": "2026/7/16", "hour": 0, "minute": 30, "second": 0,
                                      "timestamp": localAsUTC - Double(currentOffset)]
        payload.merge(changes, uniquingKeysWith: { _, new in new })
        return try JSONDecoder().decode(DSMTimeSettings.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    private func list(key: String = "vendor-future-zone", offset: Int = 28800) throws -> DSMTimeZoneList {
        let payload: [String: Any] = ["zonedata": [["value": "unused-zone", "offset": 0], ["value": key, "offset": offset]]]
        return try JSONDecoder().decode(DSMTimeZoneList.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
