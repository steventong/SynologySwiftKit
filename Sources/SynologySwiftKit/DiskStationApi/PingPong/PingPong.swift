//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

class PingPong {
    let session: Session

    init() {
        session = AlamofireClient.shared.session(timeoutIntervalForRequest: 3.6)
    }

    /**
      pingpong url
     */
    func pingpong(urls: [ConnectionType: String]) async -> [ConnectionType: String] {
        Logger.debug("send request: pingpong urls: \(urls)")
        // 多个地址并发查询
        return await withTaskGroup(of: (connnectionType: ConnectionType, url: String)?.self, returning: [ConnectionType: String].self, body: { taskGroup in
            // 子任务
            for url in urls {
                taskGroup.addTask {
                    if await self.pingpong(url: url.value) {
                        return (url.key, url.value)
                    }

                    return nil
                }
            }

            // 结果
            var data: [ConnectionType: String] = [:]
            for await result in taskGroup {
                if let result {
                    data[result.connnectionType] = result.url
                }
            }

            Logger.debug("send request: pingpong result: \(data)")
            return data
        })
    }

    /**
     pingpong test
     https://host:port/webman/pingpong.cgi?action=cors&quickconnect=true
     */
    func pingpong(url: String) async -> Bool {
        Logger.debug("send request: pingpong \(url)")
        let requestUrl = buildPingPongUrl(url: url)

        do {
            let result = try await session
                .request(requestUrl)
                .serializingDecodable(PingPongResult.self)
                .value

            return result.success
        } catch {
            switch error {
            case let AFError.sessionTaskFailed(error: sessionError):
                let sessionError = sessionError as NSError
                switch sessionError.domain {
                case NSURLErrorDomain:
                    switch sessionError.code {
                    case NSURLErrorSecureConnectionFailed:
                        // 发生了SSL错误，无法建立与该服务器的安全连接。
                        print("pingpong ssl error: \(error)")
                    default:
                        print("pingpong error: \(error)")
                    }
                default:
                    print("pingpong error: \(error)")
                }
                print("pingpong error: \(error)")
            default:
                print("pingpong error: \(error)")
            }
        }

        Logger.debug("send request: pingpong fail \(url)")
        return false
    }
}

extension PingPong {
    /**
     buildPingPongUrl
     */
    private func buildPingPongUrl(url: String) -> String {
        return "\(url)/webman/pingpong.cgi?action=cors&quickconnect=true"
    }
}
