//
//  QuickConnectModels.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/24.
//

import Foundation

extension QuickConnectClient {

    // MARK: - QuickConnectServerCommand

    /// QuickConnect 服务指令枚举
    /// QuickConnect server command enum
    enum QuickConnectServerCommand: String, Encodable {
        /// 获取设备服务器信息
        /// Get device server info
        case get_server_info

        /// 请求中继通道（relay tunnel）
        /// Request a relay tunnel
        case request_tunnel
    }

    // MARK: - QuickConnectServerId

    /// QuickConnect 服务类型 ID
    /// QuickConnect service type ID
    enum QuickConnectServerId: String, Encodable {
        /// HTTPS 模式的 DSM 服务
        /// DSM service in HTTPS mode
        case dsm_https

        /// HTTP 模式的 DSM 服务
        /// DSM service in HTTP mode
        case dsm
    }

    // MARK: - SynoGetServerInfoRequest

    /// QuickConnect `get_server_info` / `request_tunnel` 请求体
    /// Request body for QuickConnect `get_server_info` / `request_tunnel`
    struct SynoGetServerInfoRequest: Encodable {
        /// 服务类型（HTTPS/HTTP）
        /// Service type (HTTPS/HTTP)
        let id: QuickConnectServerId

        /// 服务指令
        /// Server command
        let command: QuickConnectServerCommand

        /// QuickConnect ID（设备唯一标识）
        /// QuickConnect ID (unique device identifier)
        let serverID: String

        /// 协议版本（固定为 1）
        /// Protocol version (fixed: 1)
        let version: Int

        /// 成功后是否停止（固定 false，由客户端控制）
        /// Whether to stop on success (fixed: false, controlled by client)
        let stop_when_success: Bool

        /// 出错后是否停止（固定 false）
        /// Whether to stop on error (fixed: false)
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

    // MARK: - ServerInfo

    /// QuickConnect 服务端返回的设备信息（解析 `get_server_info` / `request_tunnel` 响应）
    /// Device info returned by QuickConnect server (parsed from `get_server_info` / `request_tunnel` response)
    struct ServerInfo: Decodable {
        // MARK: Common fields

        /// 服务指令名称
        /// Server command name
        let command: String

        /// 协议版本
        /// Protocol version
        let version: Int

        /// 错误码（0 表示成功）
        /// Error code (0 means success)
        let errno: Int

        /// 子错误码
        /// Sub error code
        let suberrno: Int?

        /// 错误描述
        /// Error description
        let errinfo: String?

        /// 备用站点列表（errno=4 时需重定向到这些站点）
        /// Alternate site list (redirect to these sites when errno=4)
        let sites: [String]?

        // MARK: Success fields (errno=0)

        /// 环境信息
        /// Environment info
        let env: Env?

        /// 服务器信息（含 LAN/WAN IP、DDNS、接口列表等）
        /// Server info (LAN/WAN IP, DDNS, interface list, etc.)
        let server: Server?

        /// 服务信息（端口、relay、HTTPS 等）
        /// Service info (port, relay, HTTPS, etc.)
        let service: Service?

        /// SmartDNS 信息（用于加速 LAN 解析）
        /// SmartDNS info (for accelerating LAN resolution)
        let smartdns: Smartdns?

        // MARK: - Nested Types

        struct Env: Decodable {
            /// 控制主机地址
            /// Control host address
            let control_host: String?

            /// Relay 区域
            /// Relay region
            let relay_region: String?
        }

        struct Server: Decodable {
            /// DDNS 域名
            /// DDNS hostname
            let ddns: String?

            /// 设备状态
            /// Device state
            let ds_state: String?

            /// 外部 IP 信息
            /// External IP info
            let external: ExternalServer?

            /// 默认网关
            /// Default gateway
            let gateway: String?

            /// PingPong 检测路径
            /// PingPong check path
            let pingpong_path: String?

            /// 重定向前缀
            /// Redirect prefix
            let redirect_prefix: String?

            /// 服务器 QuickConnect ID
            /// Server QuickConnect ID
            let serverID: String?

            /// TCP 穿透端口
            /// TCP punch port
            let tcp_punch_port: Int?

            /// UDP 穿透端口
            /// UDP punch port
            let udp_punch_port: Int?

            /// 网络接口列表
            /// Network interface list
            let interface: [ExternalInterface]?
        }

        struct ExternalServer: Decodable {
            /// 外部 IPv4 地址
            /// External IPv4 address
            let ip: String?

            /// 外部 IPv6 地址
            /// External IPv6 address
            let ipv6: String?
        }

        struct ExternalInterface: Decodable {
            /// 接口 IPv4 地址
            /// Interface IPv4 address
            let ip: String?

            /// 接口名称（如 "eth0"）
            /// Interface name (e.g. "eth0")
            let name: String?

            /// 子网掩码
            /// Subnet mask
            let mask: String?

            /// IPv6 地址列表
            /// IPv6 address list
            let ipv6: [ExternalInterfaceIpV6]?
        }

        struct ExternalInterfaceIpV6: Decodable {
            /// 地址类型（0 = 本地链路地址，其他为全局）
            /// Address type (0 = link-local, others = global)
            let addr_type: Int?

            /// IPv6 地址
            /// IPv6 address
            let address: String?

            /// 前缀长度
            /// Prefix length
            let prefix_length: Int?

            /// 地址作用域
            /// Address scope
            let scope: String?
        }

        struct Service: Decodable {
            /// 服务类型 ID（"dsm" 或 "dsm_https"）
            /// Service type ID ("dsm" or "dsm_https")
            let id: String?

            /// 设备端口
            /// Device port
            let port: Int?

            /// 外部端口（路由器映射端口）
            /// External port (router-mapped port)
            let ext_port: Int?

            /// PingPong 状态
            /// PingPong status
            let pingpong: String?

            /// Relay IP 地址
            /// Relay IP address
            let relay_ip: String?

            /// Relay 域名
            /// Relay domain name
            let relay_dn: String?

            /// Relay 双栈域名
            /// Relay dual-stack domain name
            let relay_dualstack: String?

            /// Relay IPv6 地址
            /// Relay IPv6 address
            let relay_ipv6: String?

            /// Relay 端口
            /// Relay port
            let relay_port: Int?

            /// VPN IP 地址
            /// VPN IP address
            let vpn_ip: String?

            /// HTTPS IP 地址
            /// HTTPS IP address
            let https_ip: String?

            /// HTTPS 端口
            /// HTTPS port
            let https_port: Int?
        }

        struct Smartdns: Decodable {
            /// SmartDNS 主机地址
            /// SmartDNS host address
            let host: String?

            /// LAN 解析地址列表
            /// LAN resolution address list
            let lan: [String]?

            /// LAN IPv6 解析地址列表
            /// LAN IPv6 resolution address list
            let lanv6: [String]?

            /// 外网解析地址
            /// External resolution address
            let external: String?

            /// 外网 IPv6 解析地址
            /// External IPv6 resolution address
            let externalv6: String?

            /// 打洞地址（用于 P2P 穿越）
            /// Hole punch address (for P2P traversal)
            let hole_punch: String?
        }
    }
}
