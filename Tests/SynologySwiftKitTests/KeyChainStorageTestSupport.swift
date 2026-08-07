@testable import SynologySwiftKit

func makeKeyChainStorage(service: String) -> KeyChainStorage {
    KeyChainStorage(service: service, usesDataProtectionKeychain: false)
}
