//
//  File.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/10/3.
//

import Foundation

public class DeleteApi {
    public init() {
    }

    /**
     delete file

     https://xxx/webapi/entry.cgi

     api: SYNO.FileStation.Delete
     method: start
     version: 2
     path: ["/music/其他音乐目录/韩语流行&怀旧/Chakra_끝_20010303.flac"]
     accurate_progress: true

     {"data":{"taskid":"FileStation_1727917133BA0AA933"},"success":true}

     */
    public func delete(path: [String]) async throws -> Bool {
        let api = try DiskStationApi(api: .SYNO_FILE_STATION_DELETE, method: "start", version: 2, parameters: [
            "accurate_progress": true,
        ])

        let delete = try await api.requestForData(resultType: DeleteTask.self)

        Logger.info("delete: \(path), result = \(delete)")
        return delete.taskid != nil
    }
}
