//

//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum ConnectionType: String, CaseIterable, Sendable {
    
    case lan
    case wan
    case lanv6
    case wanv6
    case ddns
    case relay
    //        case lanIPv4
    //        case wan
    //        case wanIPv4
//        case smartDNSLanIPv4
//        case smartDNSLanIPv6
//
//        case lanIPv6
//        case fqdn
//
//        case smartDNSHost
//        case smartDNSWanIPv6
//        case smartDNSWanIPv4
//        case wanIPv6
//        case wanIPv4

    case custom_domain

    /// 连接类型优先级（数值越小优先级越高）
    /// Connection type priority (lower number = higher priority)
    /// - lan: 局域网直连，最低延迟 / LAN direct, lowest latency
    /// - lanv6: 局域网 IPv6 直连 / LAN IPv6 direct
    /// - ddns: 动态 DNS 域名，稳定且自动解析 / DDNS hostname, stable with auto resolution
    /// - wan: 公网 IPv4 直连 / WAN IPv4 direct
    /// - wanv6: 公网 IPv6，地址可能不稳定 / WAN IPv6, address may be unstable
    /// - relay: 中继转发，最后手段 / Relay forwarding, last resort
    private var priority: Int {
        switch self {
        case .lan: return 1
        case .lanv6: return 2
        case .ddns: return 3
        case .wan: return 4
        case .wanv6: return 5
        case .relay: return 6
        case .custom_domain: return 99
        }
    }

    /**
     get by name
     */
    public static func getByName(name: String) -> ConnectionType? {
        return ConnectionType(rawValue: name)
    }

    /**
     name
     */
    public var name: String {
        return rawValue
    }

    /**
     按序
     */
    static var ordered: [ConnectionType] {
        return allCases.sorted { $0.priority < $1.priority }
    }
}

public enum HttpType: Sendable {
    case HTTPS
    case HTTP

    public var httpScheme: String {
        switch self {
        case .HTTPS:
            "https://"
        case .HTTP:
            "http://"
        }
    }
}
