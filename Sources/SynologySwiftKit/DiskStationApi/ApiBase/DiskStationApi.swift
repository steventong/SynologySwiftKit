//
//  DiskStationApi.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

struct DiskStationApi {
    let session: URLSession

    let name: String
    let method: String
    let version: Int
    let parameters: [String: Any]
    let httpMethod: HTTPMethod
    let apiPath: String
    let requireAuthCookieHeader: Bool
    let requireAuthQueryParameter: Bool

    /// 初始化 API 请求
    init(api: DiskStationApiDefine, path: String? = nil, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: [String: Any] = [:], timeout: TimeInterval = 10,
         buildSidOnQuery: Bool? = nil, buildSidOnCookie: Bool? = nil) throws {
        // 根据地址初始化
        if let connectionUrl = DeviceConnection.shared.getCurrentConnectionUrl(),
           connectionUrl.type == .custom_domain, connectionUrl.url.hasPrefix("https://"),
           let url = URL(string: connectionUrl.url) {
            session = URLSessionFactory.createSession(timeoutIntervalForRequest: timeout, trustedSSLDomain: url.host)
        } else {
            session = URLSessionFactory.createSession(timeoutIntervalForRequest: timeout)
        }

        let apiInfo = try api.apiInfo(apiName: api.apiName, method: method, version: version, parameters: parameters)

        name = api.apiName
        self.method = apiInfo.method
        self.version = apiInfo.version
        self.parameters = apiInfo.parameters
        self.httpMethod = httpMethod

        requireAuthCookieHeader = buildSidOnCookie ?? api.requireAuthCookieHeader
        requireAuthQueryParameter = buildSidOnQuery ?? api.requireAuthQueryParameter

        if let customPath = path {
            // customPath 要用/开头
            apiPath = "/webapi/\(apiInfo.path)\(customPath)"
        } else {
            apiPath = "/webapi/\(apiInfo.path)"
        }
    }

    /// 自定义路径初始化
    init(api: DiskStationApiDefine, path: String, httpMethod: HTTPMethod = .get, parameters: [String: Any] = [:], timeout: TimeInterval = 10) {
        // 根据地址初始化
        if let connectionUrl = DeviceConnection.shared.getCurrentConnectionUrl(),
           connectionUrl.type == .custom_domain, connectionUrl.url.hasPrefix("https://"),
           let url = URL(string: connectionUrl.url) {
            session = URLSessionFactory.createSession(timeoutIntervalForRequest: timeout, trustedSSLDomain: url.host)
        } else {
            session = URLSessionFactory.createSession(timeoutIntervalForRequest: timeout)
        }

        name = api.apiName
        method = ""
        version = 1
        self.parameters = parameters
        self.httpMethod = httpMethod

        requireAuthCookieHeader = true
        requireAuthQueryParameter = false

        apiPath = path
    }

    /// 发送请求（无返回值）
    public func request() async throws {
        let _ = try await sendApiRequest(resultType: DiskStationApiResult<DiskStationApiEmptyData>.self,
                                         checkResultIsSuccess: { response in
                                             response.success
                                         },
                                         parseErrorCode: { response in
                                             response.errorCode
                                         })
    }

    /// 发送请求并返回数据
    public func requestForData<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await sendApiRequest(resultType: DiskStationApiResult<Value>.self,
                                                 checkResultIsSuccess: { response in
                                                     response.success
                                                 },
                                                 parseErrorCode: { response in
                                                     response.errorCode
                                                 })

        guard let data = apiResult.data else {
            throw DiskStationApiError.responseBodyEmptyError
        }

        return data
    }

    /// 发送请求并返回原始结果（不检查 success 状态）
    public func requestForResult<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await sendApiRequest(resultType: Value.self,
                                                 checkResultIsSuccess: { _ in true },
                                                 parseErrorCode: { _ in nil })
        return apiResult
    }

    /// 构建请求 URL（不发送请求）
    public func assembleRequestUrl() throws -> URL {
        return try buildApiUrlWithQueryParameters()
    }
}

// MARK: - Private Methods

extension DiskStationApi {
    /// 发送 API 请求
    private func sendApiRequest<Value: Decodable>(resultType: Value.Type = Value.self,
                                                  checkResultIsSuccess: (Value) -> Bool,
                                                  parseErrorCode: (Value) -> Int?) async throws -> Value {
        let apiUrl = try buildApiUrl(apiPath: apiPath)

        // 构建请求头
        var headers: [String: String] = [:]
        if let cookie = try buildAuthCookieHeader() {
            headers["Cookie"] = cookie
        }

        // 发送请求
        let response = try await sendApiRequest(httpMethod: httpMethod, apiUrl: apiUrl, headers: headers, parameters: parameters, resultType: resultType)

        // 检查业务状态
        if checkResultIsSuccess(response) {
            return response
        }

        // 处理错误
        guard let errorCode = parseErrorCode(response) else {
            throw DiskStationApiError.apiBizError(-1, "Unknown error, fetch errorCode fail")
        }

        // 根据错误码抛出对应异常
        try handleErrorCode(errorCode)

        // 这行不会执行，handleErrorCode 总是 throw
        throw DiskStationApiError.apiBizError(errorCode, "errorCode = \(errorCode)")
    }

    /// 发送 HTTP 请求
    private func sendApiRequest<Value: Decodable>(httpMethod: HTTPMethod, apiUrl: URL, headers: [String: String]? = nil,
                                                  parameters: [String: Any], resultType: Value.Type = Value.self) async throws -> Value {
        var request: URLRequest
        var requestUrl: URL = apiUrl

        if httpMethod == .post {
            request = URLRequest(url: apiUrl)
            request.httpMethod = httpMethod.rawValue
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = parameters.urlEncodedData
        } else {
            // GET 请求：参数放在 URL 上
            let apiUrlWithQueryParameters = try buildApiUrlWithQueryParameters()
            requestUrl = apiUrlWithQueryParameters
            request = URLRequest(url: apiUrlWithQueryParameters)
            request.httpMethod = httpMethod.rawValue
        }

        // 添加请求头
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // 记录请求日志
        NetworkLogger.logRequest(
            url: requestUrl,
            method: httpMethod.rawValue,
            headers: headers,
            body: request.httpBody
        )

        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            // 检查 HTTP 响应
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DiskStationApiError.responseBodyEmptyError
            }

            // 记录响应日志
            NetworkLogger.logResponse(
                url: requestUrl,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                data: data,
                duration: duration
            )

            // 解析响应
            do {
                return try JSONDecoder().decode(Value.self, from: data)
            } catch {
                Logger.error("JSON decode error: \(error), data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw DiskStationApiError.responseBodyEmptyError
            }
        } catch let error as DiskStationApiError {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: error, duration: duration)
            throw error
        } catch let urlError as URLError {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: urlError, duration: duration)
            try handleURLError(urlError)
            throw DiskStationApiError.commonUrlError(urlError.localizedDescription)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            NetworkLogger.logError(url: requestUrl, error: error, duration: duration)
            throw DiskStationApiError.commonUrlError(error.localizedDescription)
        }
    }

    /// 构建 API URL
    private func buildApiUrl(apiPath: String) throws -> URL {
        if let connection = DeviceConnection.shared.getCurrentConnectionUrl(),
           let connectionURL = URLComponents(string: "\(connection.url)\(apiPath)")?.url {
            return connectionURL
        }

        Logger.error("DiskStationApi.apiUrl, connectionURL is invalid")
        throw DiskStationApiError.requestHostNotPressentError
    }

    /// 构建 Cookie 请求头
    private func buildAuthCookieHeader() throws -> String? {
        if requireAuthCookieHeader {
            guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
                Logger.error("接口: \(name) \(method) 必须配置 sid/did cookie，但 session 不存在。（DiskStationApi.buildAuthCookieHeader）")
                throw DiskStationApiError.invalidSession(0, "session invalid, sid not exist")
            }

            if let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName) {
                return "id=\(sid); did=\(did)"
            }

            return "id=\(sid)"
        } else if let sid = parameters["sid"] {
            if let did = parameters["did"] {
                return "id=\(sid); did=\(did)"
            } else {
                return "id=\(sid)"
            }
        }

        return nil
    }

    /// 构建带查询参数的 URL
    private func buildApiUrlWithQueryParameters() throws -> URL {
        let apiUrl = try buildApiUrl(apiPath: apiPath)

        var parameters = parameters
        parameters["api"] = name
        parameters["method"] = method
        parameters["version"] = version

        if let sid = try buildAuthQueryParameter() {
            parameters["_sid"] = sid
        }

        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            Logger.error("DiskStationApi.buildRequestUrl, apiUrl is invalid: \(apiUrl) ")
            throw DiskStationApiError.requestHostNotPressentError
        }

        // 对参数的键进行自定义排序：普通键在前，_开头的键在后
        components.queryItems = parameters.sorted {
            if $0.key.hasPrefix("_") && !$1.key.hasPrefix("_") {
                return false
            } else if !$0.key.hasPrefix("_") && $1.key.hasPrefix("_") {
                return true
            } else {
                return $0.key < $1.key
            }
        }.map {
            URLQueryItem(name: $0.key, value: "\($0.value)")
        }

        guard let requestUrl = components.url else {
            Logger.error("DiskStationApi.buildRequestUrl, requestUrl is invalid: \(components) ")
            throw DiskStationApiError.requestHostNotPressentError
        }

        return requestUrl
    }

    /// 构建查询参数中的 sid
    private func buildAuthQueryParameter() throws -> String? {
        if requireAuthQueryParameter {
            guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
                Logger.error("接口: \(name) \(method) 必须配置 sid 参数，但 session 不存在。（DiskStationApi.buildAuthQueryParameter）")
                throw DiskStationApiError.invalidSession(0, "session invalid, sid not exist")
            }

            return sid
        }

        return nil
    }

    /// 处理 URL 错误
    private func handleURLError(_ error: URLError) throws {
        switch error.code {
        case .secureConnectionFailed:
            throw DiskStationApiError.sslConnectionFailed(error.localizedDescription)
        case .cannotFindHost:
            throw DiskStationApiError.canNotFindHostError(error.localizedDescription)
        default:
            throw DiskStationApiError.commonUrlError(error.localizedDescription)
        }
    }

    /// 处理业务错误码
    private func handleErrorCode(_ errorCode: Int) throws {
        // 错误码映射表
        let errorMessages: [Int: String] = [
            100: "Unknown error.",
            101: "No parameter of API, method or version.",
            102: "The requested API does not exist.",
            103: "The requested method does not exist.",
            104: "The requested version does not support the functionality.",
            108: "Failed to upload the file.",
            109: "The network connection is unstable or the system is busy.",
            110: "The network connection is unstable or the system is busy.",
            111: "The network connection is unstable or the system is busy.",
            112: "Preserve for other purpose.",
            113: "Preserve for other purpose.",
            114: "Lost parameters for this API.",
            115: "Not allowed to upload a file.",
            116: "Not allowed to perform for a demo site.",
            117: "The network connection is unstable or the system is busy.",
            118: "The network connection is unstable or the system is busy.",
            150: "Request source IP does not match the login IP.",
        ]

        // Session 相关错误码
        let sessionErrorCodes: Set<Int> = [105, 106, 107, 119]
        let sessionErrorMessages: [Int: String] = [
            105: "The logged in session does not have permission.",
            106: "Session timeout.",
            107: "Session interrupted by duplicated login.",
            119: "Invalid session.",
        ]

        if sessionErrorCodes.contains(errorCode) {
            let message = sessionErrorMessages[errorCode] ?? "Session error"
            throw DiskStationApiError.invalidSession(errorCode, message)
        }

        if errorCode >= 120 && errorCode <= 149 {
            throw DiskStationApiError.apiBizError(errorCode, "Preserve for other purpose.")
        }

        let message = errorMessages[errorCode] ?? "errorCode = \(errorCode)"
        throw DiskStationApiError.apiBizError(errorCode, message)
    }
}
