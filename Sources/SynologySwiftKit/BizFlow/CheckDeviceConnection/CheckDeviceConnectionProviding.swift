import Foundation

/// 设备连接检查协议
/// Device connection checking protocol
protocol CheckDeviceConnectionProviding {
    /// 检查当前连接状态
    /// Check current connection status
    func checkConnectionStatus() -> AsyncStream<CheckDeviceConnectionProgress>

    /// 检查当前连接状态
    /// Check current connection status
    func checkConnectionStatus(server: String, usesHTTPS: Bool) -> AsyncStream<CheckDeviceConnectionProgress>
}
