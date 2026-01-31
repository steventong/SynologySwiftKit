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

    private var priority: Int {
        switch self {
        case .lan: return 1
        case .wan: return 2
        case .lanv6: return 3
        case .wanv6: return 4
        case .ddns: return 5
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
