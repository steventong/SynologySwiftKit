//
//  File.swift
//
//
//  Created by Steven on 2024/6/22.
//

import Foundation

/**
 result model container
 */
public struct DiskStationApiResult<Data: Decodable>: Decodable {
    var success: Bool
    var error: DiskStationError?

    var data: Data?

    var errorCode: Int? {
        error?.code
    }
}

/**
 result model container
 */
public struct DiskStationError: Decodable {
    var code: Int
}

public struct DiskStationApiEmptyData: Decodable {
}
