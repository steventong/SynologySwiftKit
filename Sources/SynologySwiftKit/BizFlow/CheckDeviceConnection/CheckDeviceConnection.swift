//
//  File.swift
//
//
//  Created by Steven on 2024/4/30.
//

import Foundation

public class CheckDeviceConnection {
    let quickConnect = QuickConnect()
    let deviceConnection = DeviceConnection()
    let pingpong = PingPong()

    public init() {
    }

    /**
     check device connection status
     */
    public func checkStatus(url: String?, urlType: ConnectionType?, server: String?, enableHttps: Bool) async -> (type: ConnectionType, url: String)? {
        // ping exist url
        if let url, let urlType {
            let ping = await pingpong.pingpong(url: url)
            if ping {
                return (urlType, url)
            } else if urlType == .custom_domain {
                return nil
            }
        }

        guard let server else {
            return nil
        }

        let isQuickConnectId = await quickConnect.isQuickConnectId(server: server)

        // domain
        if !isQuickConnectId {
            let ping = await pingpong.pingpong(url: server)
            if ping {
                return (ConnectionType.custom_domain, server)
            }
            return nil
        }

        // fetch server connection by qc
        do {
            return try await quickConnect.getDeviceConnectionByQuickConnectId(quickConnectId: server, enableHttps: enableHttps)
        } catch {
            return nil
        }
    }
}
