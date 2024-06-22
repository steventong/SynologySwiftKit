//
//  File.swift
//
//
//  Created by Steven on 2024/6/21.
//

import Foundation

class EncryptionApi {
    /**
     api encryption

     api=SYNO.API.Encryption&method=getinfo&version=1
     */
    public func getApiInfoEncryption() async throws -> ApiInfoEncryption {
        let api = try DiskStationApi(api: .SYNO_API_ENCRYPTION, method: "getinfo", version: 1)

        let apiInfoEncryption = try await api.requestForData(resultType: ApiInfoEncryption.self)

        Logger.info("apiInfoEncryption: \(apiInfoEncryption)")

        return apiInfoEncryption
    }
}
