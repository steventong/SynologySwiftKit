//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

struct DiskStationApi {
    let session: Session

    let name: String
    let method: String
    let version: Int
    let parameters: Parameters
    let httpMethod: HTTPMethod
    let apiPath: String
    let requireAuthCookieHeader: Bool
    let requireAuthQueryParameter: Bool

    /**
     init
     */
    init(api: DiskStationApiDefine, path: String? = nil, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: Parameters = [:], timeout: TimeInterval = 10) throws {
        session = AlamofireClientFactory.createSession(timeoutIntervalForRequest: timeout)

        let apiInfo = try api.apiInfo(apiName: api.apiName, method: method, version: version)

        name = api.apiName
        self.method = apiInfo.method
        self.version = apiInfo.version
        self.httpMethod = httpMethod
        self.parameters = parameters

        requireAuthCookieHeader = api.requireAuthCookieHeader
        requireAuthQueryParameter = api.requireAuthQueryParameter

        if let customPath = path {
            // customPath 要用/开头
            apiPath = "/webapi/\(apiInfo.path)\(customPath)"
        } else {
            apiPath = "/webapi/\(apiInfo.path)"
        }
    }

    /**
     request for result
     */
    public func request() async throws {
        // 发送请求
        let _ = try await apiRequest(resultType: DiskStationApiResult<DiskStationApiEmptyData>.self,
                                     checkResultIsSuccess: { response in
                                         // 默认校验 result 需要满足 success = true
                                         response.success
                                     },
                                     parseErrorCode: { response in
                                         // 异常时，取 error.code
                                         response.errorCode
                                     })
        // 忽略结果
    }

    /**
     request for result data
     return data, the result is must success
     **/
    public func requestForData<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        // 发送请求
        let apiResult = try await apiRequest(resultType: DiskStationApiResult<Value>.self,
                                             checkResultIsSuccess: { response in
                                                 // 默认校验 result 需要满足 success = true
                                                 response.success
                                             },
                                             parseErrorCode: { response in
                                                 // 异常时，取 error.code
                                                 response.errorCode
                                             })

        // 结果不能为空
        guard let data = apiResult.data else {
            throw DiskStationApiError.responseBodyEmptyError
        }

        // 获取结果
        return data
    }

    /**
     request for result data, not check result success status
     **/
    public func requestForResult<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        // 发送请求, 不校验结果
        let apiResult = try await apiRequest(resultType: Value.self,
                                             checkResultIsSuccess: { _ in
                                                 // 不校验结果
                                                 true
                                             },
                                             parseErrorCode: { _ in
                                                 // 当前请求方式下，不会出现异常码
                                                 nil
                                             })
        // 结果
        return apiResult
    }

    /**
     build request Url not invoke api
     */
    public func assembleRequestUrl() throws -> URL {
        // 构造地址并返回，不请求
        return try buildApiRequestUrl()
    }
}

extension DiskStationApi {
    /**
     build request Url not invoke api
     */
    private func buildApiRequestUrl() throws -> URL {
        let apiUrl = try apiUrl(apiPath: apiPath)

        var parameters = self.parameters
        parameters["api"] = name
        parameters["method"] = method
        parameters["version"] = version

        if let sid = try buildAuthQueryParameter() {
            parameters["_sid"] = sid
        }

        // 使用 URLComponents 构建带有查询参数的 URL
        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            Logger.error("DiskStationApi.buildRequestUrl, apiUrl is invalid: \(apiUrl) ")
            throw DiskStationApiError.requestHostNotPressentError
        }

        // 对参数的键进行自定义排序：普通键在前，_开头的键在后，并且各自按字母顺序排序
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

        // 返回构建好的 URL
        guard let requestUrl = components.url else {
            Logger.error("DiskStationApi.buildRequestUrl, requestUrl is invalid: \(components) ")
            throw DiskStationApiError.requestHostNotPressentError
        }

        return requestUrl
    }

    /**
     request
     */
    private func apiRequest<Value: Decodable>(resultType: Value.Type = Value.self,
                                              checkResultIsSuccess: (Value) -> Bool,
                                              parseErrorCode: (Value) -> Int?) async throws -> Value {
        let apiUrl = try buildApiRequestUrl()

        // build cookie
        var headers: HTTPHeaders = []
        // auth header: Cookie
        if let cookie = try buildAuthCookieHeader() {
            headers.add(name: "Cookie", value: cookie)
        }

//        headers.add(name: "Content-Type", value: "application/json; charset=utf-8")
//        headers.add(name: "Accept-Charset", value: "utf-8")

        // send request & get response
        let response = await session.request(apiUrl, method: httpMethod, encoding: URLEncoding.default, headers: headers)
            .serializingDecodable(Value.self)
            .response

        // 解决请求过程中抛出的异常。业务返回值异常不在这里处理
        if let error = response.error {
            try handleApiErrors(error: error)
        }

        // empty result
        guard let responseData = response.value else {
            throw DiskStationApiError.responseBodyEmptyError
        }

        // handle success data
        if checkResultIsSuccess(responseData) == true {
            // 解析 set-cookie
            // parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))
            return responseData
        }

        // handle error result
        guard let errorCode = parseErrorCode(responseData) else {
            throw DiskStationApiError.apiBizError(-1, "Unknown error, fetch errorCode fail")
        }

        /**
         100 Unknown error.
         101 No parameter of API, method or version.
         102 The requested API does not exist.
         103 The requested method does not exist.
         104 The requested version does not support the functionality.
         105 The logged in session does not have permission.
         106 Session timeout.
         107 Session interrupted by duplicated login.
         108 Failed to upload the file.
         109 The network connection is unstable or the system is busy.
         110 The network connection is unstable or the system is busy.
         111 The network connection is unstable or the system is busy.
         112 Preserve for other purpose.
         113 Preserve for other purpose.
         114 Lost parameters for this API.
         115 Not allowed to upload a file.
         116 Not allowed to perform for a demo site.
         117 The network connection is unstable or the system is busy.
         118 The network connection is unstable or the system is busy.
         119 Invalid session.
         120-149 Preserve for other purpose.
         150 Request source IP does not match the login IP.
         */
        switch errorCode {
        case 100:
            throw DiskStationApiError.apiBizError(errorCode, "Unknown error.")
        case 101:
            throw DiskStationApiError.apiBizError(errorCode, "No parameter of API, method or version.")
        case 102:
            throw DiskStationApiError.apiBizError(errorCode, "The requested API does not exist.")
        case 103:
            throw DiskStationApiError.apiBizError(errorCode, "The requested method does not exist.")
        case 104:
            throw DiskStationApiError.apiBizError(errorCode, "The requested version does not support the functionality.")
        case 105:
            throw DiskStationApiError.invalidSession(errorCode, "The logged in session does not have permission.")
        case 106:
            throw DiskStationApiError.invalidSession(errorCode, "Session timeout.")
        case 107:
            throw DiskStationApiError.invalidSession(errorCode, "Session interrupted by duplicated login.")
        case 108:
            throw DiskStationApiError.apiBizError(errorCode, "Failed to upload the file.")
        case 109:
            throw DiskStationApiError.apiBizError(errorCode, "The network connection is unstable or the system is busy.")
        case 110:
            throw DiskStationApiError.apiBizError(errorCode, "The network connection is unstable or the system is busy.")
        case 111:
            throw DiskStationApiError.apiBizError(errorCode, "The network connection is unstable or the system is busy.")
        case 112:
            throw DiskStationApiError.apiBizError(errorCode, "Preserve for other purpose.")
        case 113:
            throw DiskStationApiError.apiBizError(errorCode, "Preserve for other purpose.")
        case 114:
            throw DiskStationApiError.apiBizError(errorCode, "Lost parameters for this API.")
        case 115:
            throw DiskStationApiError.apiBizError(errorCode, "Not allowed to upload a file.")
        case 116:
            throw DiskStationApiError.apiBizError(errorCode, "Not allowed to perform for a demo site.")
        case 117:
            throw DiskStationApiError.apiBizError(errorCode, "The network connection is unstable or the system is busy.")
        case 118:
            throw DiskStationApiError.apiBizError(errorCode, "The network connection is unstable or the system is busy.")
        case 119:
            throw DiskStationApiError.invalidSession(errorCode, "Invalid session.")
        case 150:
            throw DiskStationApiError.apiBizError(errorCode, "Request source IP does not match the login IP.")
        default:
            if errorCode >= 120 && errorCode <= 149 {
                throw DiskStationApiError.apiBizError(errorCode, "Preserve for other purpose.")
            } else {
                throw DiskStationApiError.apiBizError(errorCode, "Unknown errorCode = \(errorCode)")
            }
        }
    }

    /**
     api url
     */
    private func apiUrl(apiPath: String) throws -> URL {
        if let connection = DeviceConnection.shared.getCurrentConnectionUrl(),
           let connectionURL = URL(string: "\(connection.url)\(apiPath)") {
            return connectionURL
        }

        throw DiskStationApiError.requestHostNotPressentError
    }

    /**
      api version
     */
    private func apiVersion(apiName: String, apiVersion: Int) -> Int {
        return apiVersion
    }

    /**
     build sid cookie
     */
    private func buildAuthCookieHeader() throws -> String? {
        if requireAuthCookieHeader {
            guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
                throw DiskStationApiError.invalidSession(0, "session invalid, sid not exist")
            }

            if let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName) {
                return "id=\(sid); did=\(did)"
            }

            return "id=\(sid)"
        }

        return nil
    }

    private func buildAuthQueryParameter() throws -> String? {
        if requireAuthQueryParameter {
            guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
                throw DiskStationApiError.invalidSession(0, "session invalid, sid not exist")
            }

            return sid
        }

        return nil
    }

    /**
     handle error
     */
    private func handleApiErrors(error: AFError) throws {
        switch error {
        case let .sessionTaskFailed(error: sessionError):
            let sessionError = sessionError as NSError
            switch sessionError.domain {
            case NSURLErrorDomain:
                // error code 对照 https://juejin.cn/post/6844903838059593741
                switch sessionError.code {
                case NSURLErrorSecureConnectionFailed:
                    // 发生了SSL错误，无法建立与该服务器的安全连接。
                    throw DiskStationApiError.sslConnectionFailed(sessionError.localizedDescription)
                case NSURLErrorCannotFindHost:
                    // 未能找到使用指定主机名的服务器。
                    throw DiskStationApiError.canNotFindHostError(sessionError.localizedDescription)
                default:
                    // 没有识别出的异常
                    throw DiskStationApiError.commonUrlError(sessionError.localizedDescription)
                }
            default:
                // 没有识别出的异常
                Logger.error("DiskStationApi.handleApiErrors NSURLErrorDomain unknown domain, error \(error)")
                throw DiskStationApiError.commonUrlError(sessionError.localizedDescription)
            }
        default:
            // 没有识别出的异常
            Logger.error("DiskStationApi.handleApiErrors unknown error , error \(error)")
            throw DiskStationApiError.commonUrlError(error.localizedDescription)
        }
    }
}
