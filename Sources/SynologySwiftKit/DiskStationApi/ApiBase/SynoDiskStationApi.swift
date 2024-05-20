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
    init(api: DiskStationApiDefine, method: String, version: Int = 1, httpMethod: HTTPMethod = .get, parameters: Parameters = [:], timeout: TimeInterval = 10) {
        session = AlamofireClient.shared.session(timeoutIntervalForRequest: timeout)

        name = api.apiName
        self.method = method
        self.version = api.apiVersion(version: version)
        self.httpMethod = httpMethod
        self.parameters = parameters
        url = api.apiUrl
    }

    /**
     request for result
     */
    public func request() async throws -> Bool {
        let apiResult = try await apiRequest(resultType: SynoDiskStationApiEmptyData.self)
        return apiResult.success
    }

    /**
     request for result data
     **/
    public func request<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiResult = try await apiRequest(resultType: Value.self)
        if let data = apiResult.data {
            return data
        }

        throw SynoDiskStationApiError.responseBodyEmptyError
    }

    /**
     build request Url not invoke api
     */
    public func requestUrl() -> URL? {
        guard let apiUrl = try? apiUrl(apiUrl: url) else {
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

        components.queryItems = parameters
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: "\($0.value)") }

        // 返回构建好的 URL
        guard let requestUrl = components.url else {
            Logger.error("requestUrl is invalid: \(components) ")
            return nil
        }

        Logger.debug("synology build requestUrl: \(requestUrl)")
        return requestUrl
    }
}

extension SynoDiskStationApi {
    /**
     request
     */
    private func apiRequest<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> DiskStationApiResult<Value> {
        guard let apiUrl = try? apiUrl(apiUrl: url) else {
            // 处理获取 apiUrl 失败的情况
            throw SynoDiskStationApiError.requestHostNotPressentError
        }

        var query = parameters
        query["api"] = name
        query["method"] = method
        query["version"] = apiVersion(apiName: name, apiVersion: version)

//        Logger.debug("send request: \(name), apiUrl: \(apiUrl)")

        let response = await session.request(apiUrl.absoluteString, method: httpMethod, parameters: query)
            .serializingDecodable(DiskStationApiResult<Value>.self)
            .response

        // error handler
        try handleApiErrors(error: response.error)

        // empty result
        guard let responseValue = response.value else {
            throw SynoDiskStationApiError.responseBodyEmptyError
        }

        // handle success data
        if responseValue.success == true {
            // 解析 set-cookie
            // parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))
            return responseValue
        }

        // handle error result
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
        if responseValue.success == false {
            switch responseValue.errorCode {
            case 119:
                throw SynoDiskStationApiError.invalidSession
            default:
                throw SynoDiskStationApiError.apiBizError(responseValue.errorCode ?? -1)
            }
        }

        throw SynoDiskStationApiError.responseBodyEmptyError
    }

    /**
     api url
     */
    private func apiUrl(apiUrl: String) throws -> URL {
        if let connection = deviceConnection.getCurrentConnectionUrl(),
           let connectionURL = URL(string: "\(connection.url)\(apiUrl)") {
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
