//
//  File.swift
//
//
//  Created by Steven on 2024/5/12.
//

import Alamofire

public class DsmInfoApi {
    public init() {
    }

    /**
     dsm info
     */
    public func queryDmsInfo() async throws -> DsmInfo? {
        let api = try DiskStationApi(api: .SYNO_DSM_INFO, method: "getinfo", version: 2)

        let dsmInfo = try await api.requestForData(resultType: DsmInfo.self)

        Logger.info("dsmInfo: \(dsmInfo)")
        return dsmInfo
    }
}
