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
/// 2. 标准端点通过 `ApiInfoProviding` 获取路径和支持版本范围，再合并公共参数。
///    Standard endpoints fetch path and version range via `ApiInfoProviding`, then merge common parameters.
final class ApiEndpointResolver {
    /// API 信息提供者（弱引用，通过闭包延迟解析以避免循环依赖）
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
    /// - Throws: `SynologyError.network` 如果 Host 未配置或 API 信息拉取失败 / if host is not configured or API info fetch fails
    func resolve(_ endpoint: ApiEndpoint) async throws -> ResolvedApiEndpoint {
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
        let apiVersion = fetchApiVersion(
            requestedVersion: endpoint.version,
            minVersion: fetchedApiInfo.minVersion,
            maxVersion: fetchedApiInfo.maxVersion
        )

        // 合并调用方参数与公共参数（api / version / method）
        // Merge caller parameters with common parameters (api / version / method)
        let mergedParameters = endpoint.parameters.merging([
            "api": .string(apiName),
            "version": .int(apiVersion),
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
            version: apiVersion,
            parameters: mergedParameters,
            apiPath: apiPath,
            requireAuthCookie: endpoint.sidOnCookie ?? endpoint.requireAuthCookie,
            requireAuthQuery: endpoint.sidOnQuery ?? endpoint.requireQuerySid
        )
    }

    /// 根据请求版本和服务器支持范围，确定实际使用的版本号
    /// Determine the actual version based on requested version and server-supported range
    /// - Parameters:
    ///   - requestedVersion: 调用方请求的版本号 / Requested version
    ///   - minVersion: 服务器支持的最小版本 / Server minimum version
    ///   - maxVersion: 服务器支持的最大版本 / Server maximum version
    /// - Returns: 实际使用版本（Clamp 到 [minVersion, maxVersion]）/ Clamped version
    private func fetchApiVersion(requestedVersion: Int, minVersion: Int, maxVersion: Int) -> Int {
        min(max(minVersion, requestedVersion), maxVersion)
    }
}
