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
    let url: String

    init(api: DiskStationApiDefine, method: String, httpMethod: HTTPMethod = .get, parameters: Parameters = [:]) {
        session = AlamofireClient.shared.session()

        name = api.apiName
        self.method = method
        version = api.apiVersion
        self.httpMethod = httpMethod
        self.parameters = parameters
        url = api.apiUrl
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
        if let error = response.error {
            switch error {
            case let .sessionTaskFailed(error: sessionError):
                let sessionError = sessionError as NSError
                switch sessionError.domain {
                case NSURLErrorDomain:
                    // error code 对照 https://juejin.cn/post/6844903838059593741
                    switch sessionError.code {
                    case NSURLErrorSecureConnectionFailed:
                        // 发生了SSL错误，无法建立与该服务器的安全连接。
                        throw SynoDiskStationApiCommonError.sslConnectionFailed(sessionError.localizedDescription)
                    case NSURLErrorCannotFindHost:
                        // 未能找到使用指定主机名的服务器。
                        throw SynoDiskStationApiCommonError.canNotFindHostError(sessionError.localizedDescription)
                    default:
                        // 没有识别出的异常
                        throw SynoDiskStationApiCommonError.commonUrlError(sessionError.localizedDescription)
                    }
                default:
                    // 没有识别出的异常
                    throw SynoDiskStationApiCommonError.commonUrlError(sessionError.localizedDescription)
                }
            default:
                // 没有识别出的异常
                throw SynoDiskStationApiCommonError.commonUrlError(error.localizedDescription)
            }
        }

        // handle result
        if response.value?.success == false {
            throw SynoDiskStationApiBizError.apiBizError(response.value?.error?.code ?? -1)
        }
        // 解析 set-cookie
//        parseResponseCookieHeader(setCookieValue: response.response?.value(forHTTPHeaderField: "Set-Cookie"))

        if let data = response.value?.data {
            return data
        }

        throw SynoDiskStationApiCommonError.responseBodyEmptyError
    }
}

extension SynoDiskStationApi {
    /**
     api url
     */
    private func apiUrl(apiUrl: String) throws -> String {
        let deviceConnection = DeviceConnection()
        if let connection = deviceConnection.getCurrentConnectionUrl() {
            return "\(connection.url)\(apiUrl)"
        }

        throw SynoDiskStationApiCommonError.requestHostNotPressentError
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
    }

    /**
     result model container
     */
    private struct SynoApiAuthError: Decodable {
        var code: Int
    }
}
