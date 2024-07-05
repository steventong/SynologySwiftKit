//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum ConnectionType: Int, CaseIterable {
    case lan = 1
    case ddns = 2
    case relay = 3
    case wan = 4
    case lanv6 = 5
    case wanv6 = 6
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

    case custom_domain = 99

    /**
     get by name
     */
    public static func getByName(name: String) -> ConnectionType? {
        switch name {
        case "lan":
            .lan
        case "ddns":
            .ddns
        case "relay":
            .relay
        case "wan":
            .wan
        case "lanv6":
            .lanv6
        case "wanv6":
            .wanv6
        case "custom_domain":
            .custom_domain
        default:
            nil
        }
    }

    /**
     name
     */
    public var name: String {
        switch self {
        case .lan:
            "lan"
        case .ddns:
            "ddns"
        case .relay:
            "relay"
        case .wan:
            "wan"
        case .lanv6:
            "lanv6"
        case .wanv6:
            "wanv6"
        case .custom_domain:
            "custom_domain"
        }
    }

    /**
     按序
     */
    static var ordered: [ConnectionType] {
        return allCases.sorted { $0.rawValue < $1.rawValue }
    }
}

public enum HttpType {
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
