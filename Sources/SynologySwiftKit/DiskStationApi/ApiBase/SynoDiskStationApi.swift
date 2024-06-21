//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

struct SynoDiskStationApi {
    let session: Session

    let name: String
    let method: String
    let version: Int
    let parameters: Parameters
    let httpMethod: HTTPMethod
    let apiPath: String
    let apiIsRequiredAuth: Bool

    /**
     init
     */
    init(api: DiskStationApiDefine, path: String? = nil, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: Parameters = [:], timeout: TimeInterval = 10) throws {
        session = AlamofireClientFactory.createSession(timeoutIntervalForRequest: timeout)

        let apiInfo = try api.apiInfo(apiName: api.apiName, version: version)

        name = api.apiName
        self.method = method
        self.version = apiInfo.version
        self.httpMethod = httpMethod
        self.parameters = parameters
        apiIsRequiredAuth = api.requireAuthHeader
        apiPath = "/webapi/\(apiInfo.path)\(path ?? "")"
    }

    /**
     request for result
     */
    public func request() async throws {
        let _ = try await apiRequest(resultType: DiskStationApiResult<SynoDiskStationApiEmptyData>.self,
                                     checkResultIsSuccess: { response in response.success },
                                     parseErrorCode: { response in response.errorCode })
    }

    /**
     request for result data
     return data, the result is must success
     **/
    public func requestForData<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await apiRequest(resultType: DiskStationApiResult<Value>.self,
                                             checkResultIsSuccess: { response in response.success },
                                             parseErrorCode: { response in response.errorCode })
        if let data = apiResult.data {
            return data
        }

        throw SynoDiskStationApiError.responseBodyEmptyError
    }

    /**
     request for result data, not check result success status
     **/
    public func requestForResult<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await apiRequest(resultType: Value.self,
                                             checkResultIsSuccess: { _ in true },
                                             parseErrorCode: { _ in nil })
        return apiResult
    }

    /**
     build request Url not invoke api
     */
    public func assembleRequestUrl() throws -> URL {
        return try buildRequestUrl()
    }
}

extension SynoDiskStationApi {
    /**
     build request Url not invoke api
     */
    private func buildRequestUrl() throws -> URL {
        let apiUrl = try apiUrl(apiPath: apiPath)

        var parameters = self.parameters
        parameters["api"] = name
        parameters["method"] = method
        parameters["version"] = apiVersion(apiName: name, apiVersion: version)

//        if apiIsRequiredAuth,
//           let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) {
//            parameters["_sid"] = sid
//        }

        // 使用 URLComponents 构建带有查询参数的 URL
        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            Logger.error("apiUrl is invalid: \(apiUrl) ")
            throw SynoDiskStationApiError.requestHostNotPressentError
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
            Logger.error("requestUrl is invalid: \(components) ")
            throw SynoDiskStationApiError.requestHostNotPressentError
        }

        return requestUrl
    }

    /**
     request
     */
    private func apiRequest<Value: Decodable>(resultType: Value.Type = Value.self,
                                              checkResultIsSuccess: (Value) -> Bool,
                                              parseErrorCode: (Value) -> Int?) async throws -> Value {
        let apiUrl = try buildRequestUrl()

        // build cookie
        var headers: HTTPHeaders = []

        // auth header
        if apiIsRequiredAuth,
           let cookie = buildCookie() {
            headers.add(name: "Cookie", value: cookie)
        }

        headers.add(name: "Content-Type", value: "application/json; charset=utf-8")
        headers.add(name: "Accept-Charset", value: "utf-8")

        // Set Encoding
        var encoding: ParameterEncoding = JSONEncoding.default
        switch httpMethod {
        case .get:
            encoding = URLEncoding.default
        default:
            encoding = JSONEncoding.default
        }

        // request
        let response = await session.request(apiUrl, method: httpMethod, encoding: encoding, headers: headers)
            .serializingDecodable(Value.self)
            .response

        // debug log
//        Logger.debug(response.debugDescription)

        // error handler
        if let error = response.error {
            try handleApiErrors(error: error)
        }

        // empty result
        guard let responseData = response.value else {
            throw SynoDiskStationApiError.responseBodyEmptyError
        }

        // handle success data
        if checkResultIsSuccess(responseData) == true {
            // 解析 set-cookie
            // parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))
            return responseData
        }

        // handle error result
        let errorCode = parseErrorCode(responseData)
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
        case 105:
            throw SynoDiskStationApiError.invalidSession
        case 106:
            throw SynoDiskStationApiError.invalidSession
        case 107:
            throw SynoDiskStationApiError.invalidSession
        case 119:
            throw SynoDiskStationApiError.invalidSession
        default:
            throw SynoDiskStationApiError.apiBizError(errorCode ?? -1)
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

        throw SynoDiskStationApiError.requestHostNotPressentError
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
    private func buildCookie() -> String? {
        guard apiIsRequiredAuth == true else {
            return nil
        }

        if let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) {
            if let did = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_DID.keyName) {
                return "id=\(sid); did=\(did)"
            }

            return "id=\(sid)"
        }

        return nil
    }

    /**
     result model container
     */
    private struct DiskStationApiResult<Data: Decodable>: Decodable {
        var success: Bool
        var error: SynoApiAuthError?

        var data: Data?

        var errorCode: Int? {
            error?.code
        }
    }

    /**
     result model container
     */
    private struct SynoApiAuthError: Decodable {
        var code: Int
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
                    throw SynoDiskStationApiError.sslConnectionFailed(sessionError.localizedDescription)
                case NSURLErrorCannotFindHost:
                    // 未能找到使用指定主机名的服务器。
                    throw SynoDiskStationApiError.canNotFindHostError(sessionError.localizedDescription)
                default:
                    // 没有识别出的异常
                    throw SynoDiskStationApiError.commonUrlError(sessionError.localizedDescription)
                }
            default:
                // 没有识别出的异常
                Logger.error("SynoDiskStationApi.handleApiErrors NSURLErrorDomain unknown domain, error \(error)")
                throw SynoDiskStationApiError.commonUrlError(sessionError.localizedDescription)
            }
        default:
            // 没有识别出的异常
            Logger.error("SynoDiskStationApi.handleApiErrors unknown error , error \(error)")
            throw SynoDiskStationApiError.commonUrlError(error.localizedDescription)
        }
    }
}
