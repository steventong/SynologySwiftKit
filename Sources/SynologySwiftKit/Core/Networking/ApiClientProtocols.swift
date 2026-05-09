//
//  ApiClientProviding.swift
//  SynologySwiftKit
//
//  Created by Steven on 2024/4/27.
//

import Foundation

protocol ConnectionStateProviding {
    var connection: (type: ConnectionType, url: String)? { get }
}

protocol ConnectionStateUpdating {
    func updateConnection(type: ConnectionType, url: String)
}

protocol SessionStateProviding {
    var session: (sid: String, did: String?)? { get }
}

protocol SessionStateUpdating {
    func updateSession(sid: String, did: String?)
    func clearSession()
}

protocol ApiRequestSending {
    func request<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T
    func requestEnvelope<T: Decodable>(_ endpoint: ApiEndpoint) async throws -> T
}

protocol ApiURLBuilding {
    func buildUrl(_ endpoint: ApiEndpoint) async throws -> URL
}

protocol RawRequestSending {
    func request<T: Decodable>(url: URL, httpMethod: HTTPMethod, headers: [String: String]?, body: Data?, timeout: TimeInterval) async throws -> T
}

typealias ApiEndpointClient = ApiRequestSending & ApiURLBuilding

/// Full internal client capability set. Prefer narrower protocols in feature services.
typealias ApiClientProviding = ApiRequestSending
    & ApiURLBuilding
    & RawRequestSending
    & ConnectionStateProviding
    & ConnectionStateUpdating
    & SessionStateProviding
    & SessionStateUpdating
