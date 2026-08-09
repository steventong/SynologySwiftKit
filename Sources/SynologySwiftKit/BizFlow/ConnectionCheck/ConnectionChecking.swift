import Foundation

/// 连接检查协议
/// Connection checking protocol
protocol ConnectionChecking {
    /// 使用已保存的服务器信息检查当前连接状态
    /// Check current connection status using saved server info
    func check() -> AsyncStream<ConnectionCheckProgress>

    /// 自动识别协议并优先尝试 HTTPS
    /// Automatically resolve the protocol with HTTPS preferred
    func check(server: String) -> AsyncStream<ConnectionCheckProgress>

    /// 使用指定服务器检查连接状态
    /// Check connection status for a specific server
    func check(server: String, usesHTTPS: Bool) -> AsyncStream<ConnectionCheckProgress>
}
