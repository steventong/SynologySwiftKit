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
    init(api: DiskStationApiDefine, method: String, version: Int, httpMethod: HTTPMethod = .get, parameters: Parameters = [:], timeout: TimeInterval = 10) {
        session = AlamofireClient.shared.session(timeoutIntervalForRequest: timeout)

        name = api.apiName
        self.method = method
        self.version = api.apiVersion(version: version)
        self.httpMethod = httpMethod
        self.parameters = parameters
        url = api.apiUrl
    }

    /**
     request
     */
    public func request() async throws {
        let ignored = try await request(resultType: SynoDiskStationApiEmptyData.self)
    }

    /**
     request
     */
    public func request<Value: Decodable>(resultType: Value.Type = Value.self) async throws -> Value {
        let apiUrl = try apiUrl(apiUrl: url)

        var parameters = self.parameters
        parameters["api"] = name
        parameters["method"] = method
        parameters["version"] = apiVersion(apiName: name, apiVersion: version)

        Logger.debug("send request: \(name), apiUrl: \(apiUrl)")

        let response = await session.request(apiUrl, method: httpMethod, parameters: parameters)
            .serializingDecodable(DiskStationApiResult<Value>.self)
            .response

        // error handler
        try handleApiErrors(error: response.error)

        // empty result
        guard let responseValue = response.value else {
            throw SynoDiskStationApiError.responseBodyEmptyError
        }

        // handle success data
        if responseValue.success == true,
           let data = response.value?.data {
            // 解析 set-cookie
            //        parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))

            return data
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
}

extension SynoDiskStationApi {
    /**
     api url
     */
    private func apiUrl(apiUrl: String) throws -> String {
        if let connection = deviceConnection.getCurrentConnectionUrl() {
            return "\(connection.url)\(apiUrl)"
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
