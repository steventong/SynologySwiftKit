//
//  File.swift
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public enum SynologyUserLoginStep {
    case STEP_START

    case QC_FETCH_CONNECTION
    case QC_FETCH_CONNECTION_SUCCESS

    case USER_LOGIN(FetchConnectionType)
    case USER_LOGIN_SUCCESS(FetchConnectionType)

    case STEP_FINISH
}

public enum FetchConnectionType {
    case QUICK_CONNECT_ID

    case CUSTOM_DOMAIN
}
