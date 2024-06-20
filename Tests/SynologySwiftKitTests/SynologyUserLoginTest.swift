//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

@testable import SynologySwiftKit
import XCTest

final class SynologyUserLoginTest: XCTestCase {
    /**
     删除缓存后测试
     */
    func testUserLoginWithoutCache() async throws {
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.SYNOLOGY_SERVER_URL(SecretKey.quickConnectId).keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_URL.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_CONNECTION_TYPE.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_ID.keyName)
//        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.DISK_STATION_AUTH_DEVICE_NAME.keyName)

        let synologyUserLogin = SynologyUserLogin()
        let authResult = try await synologyUserLogin.login(server: SecretKey.quickConnectId, username: SecretKey.username, password: SecretKey.password,
                                                           otpCode: "", enableHttps: true,
                                                           onLoginStepUpdate: { step in
                                                               print("当前流程 \(step)")
                                                           }, onConnectionFetch: { type, url in
                                                               print("连接信息 \(type) \(url)")
                                                           })

        Logger.info("authResult: \(authResult)")
        
    }

    func testLoginWithEncrption() async throws {
        let apiInfo = ApiInfoApi()
        
        let encryption = try await apiInfo.getApiInfoEncryption()
        
        debugPrint(encryption)
        
        let public_key = encryption.public_key
        let cipherkey = encryption.cipherkey
        let ciphertoken = encryption.ciphertoken
        let server_time = encryption.server_time
        let random_passphrase = _random_AES_passphrase(length: 501)
        
        debugPrint(random_passphrase)
        
        var params: [String: Any] = [:]
        params[ciphertoken] = server_time
        
        
       let a = UInt64(public_key, radix: 16)
        let b = UInt64("10001", radix: 16)
        
        _encrypt_RSA(modulus: a!, passphrase: b!, text: random_passphrase)
    }
    
    
    func _random_AES_passphrase(length: Int) -> Data {
        let available = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()_+-/"
        var key = Data()
        var remainingLength = length

        while remainingLength > 0 {
            let randomIndex = Int(arc4random_uniform(UInt32(available.count)))
            if let randomChar = available.randomElement() {
                key.append(randomChar.asciiValue!)
            }
            remainingLength -= 1
        }

        return key
    }
    
    func _encrypt_RSA(modulus: UInt64, passphrase: UInt64, text: Data ) {
        
    }

}
