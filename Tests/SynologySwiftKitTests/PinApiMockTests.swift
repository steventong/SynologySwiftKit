import XCTest

@testable import SynologySwiftKit

// MARK: - Mock ApiClient

class MockApiClient: ApiClientProviding {

    // 存储预设的返回结果（Key 可以是 apiName + method）
    var mockResults: [String: Any] = [:]
    // 存储预设的错误
    var mockError: Error?
    // 记录最后一次请求的 Endpoint，用于断言验证
    var lastEndpoint: ApiEndpoint?

    // 设置 Mock 数据辅助方法
    func setMockResult<T>(_ result: T, for api: String, method: String) {
        let key = "\(api):\(method)"
        mockResults[key] = result
    }

    // MARK: - ApiClientProviding Implementation

    func request<T>(_ endpoint: ApiEndpoint, rawResponse: Bool) async throws -> T
    where T: Decodable {
        lastEndpoint = endpoint

        if let error = mockError {
            throw error
        }

        // 简单模拟：根据 API 和 Method 查找预设结果
        let key = "\(endpoint.apiName):\(endpoint.method)"

        if let result = mockResults[key] as? T {
            return result
        }

        // 如果找不到匹配的 Mock 数据，抛出致命错误，方便调试
        fatalError("No mock result found for key: \(key). Expected type: \(T.self)")
    }

    func request(_ endpoint: ApiEndpoint) async throws {
        _ = try await request(endpoint, rawResponse: false) as SynologySwiftKit.EmptyData
    }

    func buildUrl(_ endpoint: ApiEndpoint) throws -> URL {
        return URL(string: "https://mock.synology.com/webapi/\(endpoint.apiName)")!
    }
}

// MARK: - PinApi Tests

final class PinApiTests: XCTestCase {

    var api: PinApi!
    var mockClient: MockApiClient!

    override func setUp() {
        super.setUp()
        // 初始化 Mock Client
        mockClient = MockApiClient()
        // 注入依赖
        api = PinApi(apiClient: mockClient)
    }

    // 测试 pin list 成功场景
    func testListPins_Success() async throws {
        // 1. Arrange (准备数据)
        let expectedItem = PinItem(
            id: "unique_id_123",
            type: .artist,
            name: "Test Artist",
            criteria: PinCriteria.artist("Test Artist")
        )
        let mockResponse = PinListResult(
            items: [expectedItem],
            offset: 0,
            total: 1
        )

        // 配置 Mock 返回
        mockClient.setMockResult(mockResponse, for: "SYNO.AudioStation.Pin", method: "list")

        // 2. Act (执行操作)
        let (total, items) = try await api.list(limit: 10, offset: 0)

        // 3. Assert (验证结果)
        XCTAssertEqual(total, 1)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Test Artist")
        XCTAssertEqual(items.first?.type, .artist)

        // 验证请求参数是否正确
        XCTAssertEqual(mockClient.lastEndpoint?.apiName, "SYNO.AudioStation.Pin")
        XCTAssertEqual(mockClient.lastEndpoint?.method, "list")
        XCTAssertEqual(mockClient.lastEndpoint?.parameters["limit"] as? Int, 10)
    }

    // 测试 pin list 失败场景
    func testListPins_Failure() async {
        // Arrange
        mockClient.mockError = SynologyError.network(.responseEmpty)

        // Act & Assert
        do {
            _ = try await api.list()
            XCTFail("Should throw error")
        } catch let error as SynologyError {
            // 验证抛出的错误类型
            if case .network(.responseEmpty) = error {
                // Success
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
