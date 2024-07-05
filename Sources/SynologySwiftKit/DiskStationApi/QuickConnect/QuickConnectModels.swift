//
//  File.swift
//
//
//  Created by Steven on 2024/4/24.
//

import Foundation

extension QuickConnectApi {
    enum QuickConnectServerCommand: String, Encodable {
        case get_server_info
        case request_tunnel
    }

    enum QuickConnectServerId: String, Encodable {
        case dsm_https
        case dsm
    }

    struct SynoGetServerInfoRequest: Encodable {
        let id: QuickConnectServerId
        let command: QuickConnectServerCommand
        let serverID: String
        let version: Int
        let stop_when_success: Bool
        let stop_when_error: Bool

        init(id: QuickConnectServerId, command: QuickConnectServerCommand, serverID: String) {
            self.id = id
            self.command = command
            self.serverID = serverID
            version = 1
            stop_when_success = false
            stop_when_error = false
        }
    }

    struct ServerInfo: Decodable {
        // common
        let command: String
        let version: Int
        let errno: Int
        let suberrno: Int?
        let errinfo: String?

        //  "errno": 4,  "suberrno": 3
        let sites: [String]?

        //  find serverInfo "errno": 0,
        let env: Env?
        let server: Server?
        let service: Service?
        let smartdns: Smartdns?

        struct Env: Decodable {
            let control_host: String?
            let relay_region: String?
        }

        struct Server: Decodable {
            let ddns: String?
            let ds_state: String?
            let external: ExternalServer?
//            let fqdn: String?
            let gateway: String?
//            let ipv6_tunnel: [String]?
//            let is_bsm: Bool?
            let pingpong_path: String?
            let redirect_prefix: String?
            let serverID: String?
            let tcp_punch_port: Int?
            let udp_punch_port: Int?
            let interface: [ExternalInterface]?
        }

        struct ExternalServer: Decodable {
            let ip: String?
            let ipv6: String?
        }

        struct ExternalInterface: Decodable {
            let ip: String?
            let name: String?
            let mask: String?
            let ipv6: [ExternalInterfaceIpV6]?
        }

        struct ExternalInterfaceIpV6: Decodable {
            let addr_type: Int?
            let address: String?
            let prefix_length: Int?
            let scope: String?
        }

        struct Service: Decodable {
            let port: Int?
            let ext_port: Int?
            let pingpong: String?
//            let pingpong_desc: [String]?
            let relay_ip: String?
            let relay_dn: String?
            let relay_port: Int?
            let vpn_ip: String?
            let https_ip: String?
            let https_port: Int?
        }

        struct Smartdns: Decodable {
            let host: String?
            let lan: [String]?
            let lanv6: [String]?
            let hole_punch: String?
        }
    }
}
