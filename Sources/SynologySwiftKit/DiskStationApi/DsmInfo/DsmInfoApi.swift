//
//  File.swift
//
//
//  Created by Steven on 2024/5/12.
//

import Alamofire

public class DsmInfoApi {
    let session: Session

    public init() {
        session = AlamofireClient.shared.session()
    }

    /**
     dsm info
     */
    public func queryDmsInfo() async throws -> DsmInfo? {
        let api = SynoDiskStationApi(api: .SYNO_DSM_INFO, method: "getinfo", version: 2)

        let dsmInfo = try await api.request(resultType: DsmInfo.self)

        Logger.info("dsmInfo: \(dsmInfo)")
        return dsmInfo
    }
}
