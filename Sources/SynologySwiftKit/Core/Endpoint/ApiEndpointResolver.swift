import Foundation

// MARK: - ApiEndpointResolver

/// API 端点解析器
/// API endpoint resolver
///
/// 负责将 `ApiEndpoint`（逻辑描述）解析为 `ResolvedApiEndpoint`（含路径 + 版本 + 参数的可执行描述）。
/// Resolves `ApiEndpoint` (logical description) into `ResolvedApiEndpoint` (executable description with path, version, and parameters).
///
/// 解析流程：
/// Resolution flow:
/// 1. 自定义路径端点直接返回，不查询 API 信息。
///    Custom path endpoints are returned directly without querying API info.
/// 2. 标准端点通过 `ApiInfoProviding` 获取路径，校验声明版本是否受支持，再合并公共参数。
///    Standard endpoints fetch the path, validate the declared version, and merge common parameters.
final class ApiEndpointResolver {
    /// 通过闭包延迟获取 API 信息提供者，避免循环依赖。
    /// API info provider (lazily resolved via closure to avoid circular dependency)
    private let apiInfoProvider: () -> ApiInfoProviding?

    /// 初始化解析器
    /// Initialize resolver
    /// - Parameter apiInfoProvider: 延迟获取 API 信息提供者的闭包 / Closure to lazily retrieve API info provider
    init(apiInfoProvider: @escaping () -> ApiInfoProviding?) {
        self.apiInfoProvider = apiInfoProvider
    }

    /// 解析端点（异步）
    /// Resolve endpoint (async)
    /// - Parameter endpoint: 待解析的 API 端点 / API endpoint to resolve
    /// - Returns: 可执行的解析端点（含路径、版本、参数）/ Executable resolved endpoint (path, version, parameters)
    /// - Throws: API 信息查询错误；声明版本不受支持时抛出 `SynologyError.api(code: 104)`。
    func resolve(_ endpoint: ApiEndpoint) async throws -> ResolvedApiEndpoint {
        guard endpoint.parameters["version"] == nil else {
            throw SynologyError.api(code: -1, message: "Declare the API version using ApiEndpoint.version, not parameters[\"version\"].")
        }
        if endpoint.isCustomPath {
            return ResolvedApiEndpoint(
                name: endpoint.apiName,
                method: endpoint.method,
                version: endpoint.version,
                parameters: endpoint.parameters,
                apiPath: endpoint.fullPath ?? "",
                requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
                requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid
            )
        }

        guard let apiInfoProvider = apiInfoProvider() else {
            throw SynologyError.network(message: "Host not configured")
        }

        let apiName = endpoint.apiName
        let fetchedApiInfo = try await apiInfoProvider.getApiInfoByApiName(apiName: apiName)
        guard endpoint.version >= fetchedApiInfo.minVersion,
              endpoint.version <= fetchedApiInfo.maxVersion else {
            throw SynologyError.api(
                code: SynologyErrorCode.versionDoesNotSupport.rawValue,
                message: "API \(apiName) version \(endpoint.version) is outside the server-supported range \(fetchedApiInfo.minVersion)...\(fetchedApiInfo.maxVersion)."
            )
        }

        // 合并调用方参数与公共参数（api / version / method）
        // Merge caller parameters with common parameters (api / version / method)
        let mergedParameters = endpoint.parameters.merging([
            "api": .string(apiName),
            "version": .int(endpoint.version),
            "method": .string(endpoint.method),
        ]) { current, _ in current }

        let apiPath: String
        if let pathSuffix = endpoint.pathSuffix {
            apiPath = "/webapi/\(fetchedApiInfo.path)\(pathSuffix)"
        } else {
            apiPath = "/webapi/\(fetchedApiInfo.path)"
        }

        return ResolvedApiEndpoint(
            name: apiName,
            method: endpoint.method,
            version: endpoint.version,
            parameters: mergedParameters,
            apiPath: apiPath,
            requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
            requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid
        )
    }
}
