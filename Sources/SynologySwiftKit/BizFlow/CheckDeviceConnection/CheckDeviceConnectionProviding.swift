import Foundation

/// 设备连接检查协议
/// Device connection checking protocol
public protocol CheckDeviceConnectionProviding {
    /// 检查当前连接状态
    /// Check current connection status
    func checkConnectionStatus(fetchNewConnectionUrl: Bool) -> AsyncStream<CheckDeviceConnectionProgress>
}
