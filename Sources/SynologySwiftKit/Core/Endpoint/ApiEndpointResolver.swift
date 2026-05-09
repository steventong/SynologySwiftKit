import Foundation

final class ApiEndpointResolver {
    private let apiInfoProvider: () -> ApiInfoProviding?

    init(apiInfoProvider: @escaping () -> ApiInfoProviding?) {
        self.apiInfoProvider = apiInfoProvider
    }

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

    private func fetchApiVersion(requestedVersion: Int, minVersion: Int, maxVersion: Int) -> Int {
        min(max(minVersion, requestedVersion), maxVersion)
    }
}
