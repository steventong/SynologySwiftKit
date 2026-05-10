import Foundation

public protocol CredentialStorage: AnyObject, Sendable {
    func saveCredentials(server: String, username: String, password: String, usesHTTPS: Bool)
    func getCredentials() -> SynologyCredentials?
    func removeCredentials()
}

public protocol SessionStorage: AnyObject, Sendable {
    func saveSessionInfo(sid: String, did: String?)
    func getSessionInfo() -> (sid: String, did: String?)?
    func removeSessionInfo()
}

public protocol ConnectionStorage: AnyObject, Sendable {
    func saveConnectionInfo(url: String, typeString: String)
    func getConnectionInfo() -> (url: String, typeString: String)?
    func removeConnectionInfo()
}

public protocol DeviceIdentityStorage: AnyObject, Sendable {
    func saveDeviceInfo(_ did: String, _ name: String)
    func getDeviceInfo() -> (String, String)?
}

public typealias SensitiveStorage = CredentialStorage
    & SessionStorage
    & ConnectionStorage
    & DeviceIdentityStorage
