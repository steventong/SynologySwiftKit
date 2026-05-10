import Foundation

protocol SynologyUserLoginProviding {
    func login(server: String, usesHTTPS: Bool, username: String, password: String, otpCode: String?, shouldSavePassword: Bool) -> AsyncStream<SynologyUserLoginProgress>
    func login() -> AsyncStream<SynologyUserLoginProgress>
}
