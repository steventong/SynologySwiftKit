//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Alamofire
import Foundation

actor Auth {
    let session: Session

    init() {
        session = AlamofireClient.shared.session()
    }

    /**
     user login
     */
    func userLogin(server: String, username: String, password: String, optCode: String? = nil) {
        Logger.debug("send request: userLogin, \(server), \(username)")

        let api = SynoDiskStationApi(api: .SYNO_API_AUTH, method: "login", parameters: [
            "account": username,
            "passwd": password,
//            "version": 6,
//            //        "session": deviceName,
//            "format": "cookie",
//            "otp_code": otpCode ?? "",
//            "enable_syno_token": "no",
//            "enable_device_token": "yes",
//            "device_name": deviceName,
//            "device_id": deviceId
        ])

//        let apiInfoList = try await api.request(resultType: [String: ApiInfoNode].self)

//        Logger.info("apiInfo: \(apiInfoList)")
    }
}
