//
//  File.swift
//  SynologySwiftKit
//
//  Created by Steven on 2025/1/19.
//

import Alamofire

class DynamicServerTrustManager: ServerTrustManager {
    
//    private var evaluators: [String: ServerTrustEvaluating]
//
//    init() {
//        self.evaluators = [:]
//        super.init(allHostsMustBeEvaluated: false, evaluators: [:])
//    }
//
//    // 添加动态信任的域名
//    func addTrustedDomain(_ domain: String) {
//        evaluators[domain] = DisabledTrustEvaluator() // 允许所有证书
//    }
//
//    // 自定义 evaluatorForHost 方法以处理动态域名
//    override func evaluator(forHost host: String) throws -> ServerTrustEvaluating? {
//        return evaluators[host]
//    }
}
