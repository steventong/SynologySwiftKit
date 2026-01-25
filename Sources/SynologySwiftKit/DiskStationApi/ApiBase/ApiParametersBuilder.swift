//
//  ApiParametersBuilder.swift
//  SynologySwiftKit
//
//  Created by SynologySwiftKit on 2026/01/25.
//

import Foundation

/// API 参数构建器
/// API Parameters Result Builder
@resultBuilder
public struct ApiParametersBuilder {
    public typealias Parameter = (String, Any?)
    public typealias Parameters = [String: Any]

    // 支持单个参数元组 (Key, Value)
    public static func buildExpression(_ expression: Parameter) -> Parameters {
        if let value = expression.1 {
            return [expression.0: value]
        }
        return [:]
    }

    // 支持参数字典 [Key: Value]
    public static func buildExpression(_ expression: Parameters) -> Parameters {
        return expression
    }

    // 忽略 Void (用于 if 没有 else 的情况)
    public static func buildExpression(_ expression: Void) -> Parameters {
        return [:]
    }

    // 组合多个表达式的结果
    public static func buildBlock(_ components: Parameters...) -> Parameters {
        var result: Parameters = [:]
        for component in components {
            result.merge(component) { (_, new) in new }
        }
        return result
    }

    // 支持 if 语句
    public static func buildOptional(_ component: Parameters?) -> Parameters {
        return component ?? [:]
    }

    // 支持 if-else 语句
    public static func buildEither(first component: Parameters) -> Parameters {
        return component
    }

    public static func buildEither(second component: Parameters) -> Parameters {
        return component
    }

    // 支持数组循环 (Array)
    public static func buildArray(_ components: [Parameters]) -> Parameters {
        var result: Parameters = [:]
        for component in components {
            result.merge(component) { (_, new) in new }
        }
        return result
    }
}
