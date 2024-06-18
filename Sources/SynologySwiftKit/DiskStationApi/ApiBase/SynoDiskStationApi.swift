//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation
import SwiftyJSON

struct SynoDiskStationApi {
    let session: Session
    let quickConnectApi = QuickConnectApi()
    let deviceConnection = DeviceConnection()

    let name: String
    let method: String
    let version: Int
    let parameters: Parameters
    let httpMethod: HTTPMethod
    let url: String

    /**
     init
     */
    init(api: DiskStationApiDefine, path: String? = nil, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: Parameters = [:], timeout: TimeInterval = 10) {
        session = AlamofireClient.shared.session(timeoutIntervalForRequest: timeout)

        name = api.apiName
        self.method = method
        self.version = api.apiVersion(version: version)
        self.httpMethod = httpMethod
        self.parameters = parameters

        if let path {
            url = api.apiUrl + path
        } else {
            url = api.apiUrl
        }
    }

    /**
     request for result
     */
    public func request() async throws -> Bool {
        let apiResult = try await apiRequest(resultType: DiskStationApiResult<SynoDiskStationApiEmptyData>.self, isResultSuccess: { response in
            response.success
        }, parseErrorCode: { response in
            response.errorCode
        })

        return true
    }

    /**
     request for result data
     **/
    public func requestForData<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await apiRequest(resultType: DiskStationApiResult<Value>.self, isResultSuccess: { response in
            response.success
        }, parseErrorCode: { response in
            response.errorCode
        })
        if let data = apiResult.data {
            return data
        }

        throw SynoDiskStationApiError.responseBodyEmptyError
    }

    /**
     request for result data
     **/
    public func requestForResult<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await apiRequest(resultType: Value.self, isResultSuccess: { _ in
            // 不检查结果，直接返回结果
            true
        }, parseErrorCode: { _ in
            nil
        })

        return apiResult
    }

    /**
     build request Url not invoke api
     */
    public func assembleRequestUrl() -> URL? {
        return buildRequestUrl()
    }
}

extension SynoDiskStationApi {
    /**
     build request Url not invoke api
     */
    public func buildRequestUrl() -> URL? {
        guard let apiUrl = try? apiUrl(apiPath: url) else {
            // 处理获取 apiUrl 失败的情况
            return nil
        }

        var parameters = self.parameters
        parameters["api"] = name
        parameters["method"] = method
        parameters["version"] = apiVersion(apiName: name, apiVersion: version)

        // 使用 URLComponents 构建带有查询参数的 URL
        guard var components = URLComponents(url: apiUrl, resolvingAgainstBaseURL: false) else {
            Logger.error("apiUrl is invalid: \(apiUrl) ")
            return nil
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
        }.map { URLQueryItem(name: $0.key, value: "\($0.value)") }

        // 返回构建好的 URL
        guard let requestUrl = components.url else {
            Logger.error("requestUrl is invalid: \(components) ")
            return nil
        }

//        Logger.debug("synology build requestUrl: \(requestUrl)")
        return requestUrl
    }

    /**
     request
     */
    private func apiRequest<Value: Decodable>(resultType: Value.Type = Value.self,
                                              isResultSuccess: (Value) -> Bool,
                                              parseErrorCode: (Value) -> Int?) async throws -> Value {
        guard let apiUrl = buildRequestUrl() else {
            // 处理获取 apiUrl 失败的情况
            throw SynoDiskStationApiError.requestHostNotPressentError
        }

        // build cookie
        var headers: HTTPHeaders = []
        if let cookie = buildCookie() {
            headers.add(name: "Cookie", value: cookie)
        }

        headers.add(name: "Content-Type", value: "application/json; charset=utf-8")
        headers.add(name: "Accept-Charset", value: "utf-8")

        //        Logger.debug("send request: \(name), apiUrl: \(apiUrl)")

        let response = await session.request(apiUrl.absoluteString, method: httpMethod, encoding: JSONEncoding.default, headers: headers)
            .serializingData()
            .response

        // debug log
//        Logger.debug(response.debugDescription)

        // error handler
        try handleApiErrors(error: response.error)

        // empty result
        guard let responseData = response.value else {
            throw SynoDiskStationApiError.responseBodyEmptyError
        }

        guard let resultObj = try parseStringToObj(responseData: responseData, resultType: Value.self) else {
            throw SynoDiskStationApiError.responseBodyEmptyError
        }

        let resultIsSuccess = isResultSuccess(resultObj)
        // handle success data
        if resultIsSuccess == true {
            // 解析 set-cookie
            // parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))
            return resultObj
        } else {
            // handle error result
            let errorCode = parseErrorCode(resultObj)

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

            throw SynoDiskStationApiError.responseBodyEmptyError
        }
    }

    private func parseStringToObj<Value: Decodable>(responseData: Data, resultType: Value.Type = Value.self) throws -> Value? {
        let json = try JSON(data: responseData)
        if let jsonObject = json.dictionaryObject {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            let valueType = try JSONDecoder().decode(Value.self, from: jsonData)
            return valueType
        }

        return nil
    }

    /**
     api url
     */
    private func apiUrl(apiPath: String) throws -> URL {
        if let connection = deviceConnection.getCurrentConnectionUrl(),
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
    private func handleApiErrors(error: AFError?) throws {
        guard let error else {
            return
        }

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
