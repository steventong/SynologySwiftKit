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

    case QC_USER_LOGIN
    case QC_USER_LOGIN_SUCCESS

    case CUSTOM_DOMAIN_USER_LOGIN
    case CUSTOM_DOMAIN_USER_LOGIN_SUCCESS

    case STEP_FINISH
}
