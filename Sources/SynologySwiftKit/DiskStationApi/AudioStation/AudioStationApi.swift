//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public class AudioStationApi {
    public init() {
    }
}

extension AudioStationApi {
    func getSessionId() throws -> String {
        guard let sid = UserDefaults.standard.string(forKey: UserDefaultsKeys.DISK_STATION_AUTH_SESSION_SID.keyName) else {
            throw DiskStationApiError.invalidSession(0, "invalid session, session not exist")
        }

        return sid
    }
}
