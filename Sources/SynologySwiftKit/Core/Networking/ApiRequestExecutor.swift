import Foundation
import SwiftHttpClient

// MARK: - ApiRequestExecutor

/// API 请求执行器
/// API request executor
///
/// 负责执行实际的 HTTP 请求，并按顺序执行所有注册的拦截器。
/// Responsible for executing actual HTTP requests and running all registered interceptors in order.
///
/// 拦截器执行顺序 / Interceptor execution order:
/// - 请求阶段（adapt）：正向执行（注册顺序）/ Request phase (adapt): forward order (registration order)
/// - 响应阶段（process）：逆向执行（注册逆序）/ Response phase (process): reverse order
final class ApiRequestExecutor {
    private let httpClientFactory: SynologyHTTPClientFactory
    /// 拦截器快照提供者（通过闭包延迟获取，避免强引用）
    /// Interceptor snapshot provider (lazily fetched via closure to avoid strong reference)
    private let interceptorsProvider: () -> [RequestInterceptor]
    private let responseDecoder: ApiResponseDecoder
    private let errorMapper: SynologyErrorMapper

    /// 初始化执行器
    /// Initialize executor
    /// - Parameters:
    ///   - httpClientFactory: HTTP 客户端工厂 / HTTP client factory
    ///   - interceptorsProvider: 拦截器列表提供者（快照，避免并发竞争）/ Interceptor list provider (snapshot)
    ///   - responseDecoder: 响应解码器 / Response decoder
    ///   - errorMapper: URL 错误映射器 / URL error mapper
    init(
        httpClientFactory: @escaping SynologyHTTPClientFactory,
        interceptorsProvider: @escaping () -> [RequestInterceptor],
        responseDecoder: ApiResponseDecoder = ApiResponseDecoder(),
        errorMapper: SynologyErrorMapper = SynologyErrorMapper()
    ) {
        self.httpClientFactory = httpClientFactory
        self.interceptorsProvider = interceptorsProvider
        self.responseDecoder = responseDecoder
        self.errorMapper = errorMapper
    }

    /// 执行 HTTP 请求（含拦截器链处理）
    /// Execute HTTP request (with interceptor chain processing)
    ///
    /// 执行流程：
    /// Execution flow:
    /// 1. 执行所有请求拦截器（adapt）
    /// 2. 发送 HTTP 请求
    /// 3. 执行所有响应拦截器（process）
    /// 4. 解码响应
    ///
    /// - Parameters:
    ///   - type: 期望的解码类型 / Expected decode type
    ///   - request: 已构建的 URLRequest / Built URLRequest
    ///   - endpoint: 原始端点（传递给拦截器）/ Original endpoint (passed to interceptors)
    ///   - timeout: 超时时间（秒）/ Timeout in seconds
    ///   - trustedSSLDomain: 可信 SSL 域名（用于自签名证书）/ Trusted SSL domain (for self-signed certs)
    /// - Returns: 解码后的结果 / Decoded result
    /// - Throws: `SynologyError` 各类业务或网络错误 / Various business or network errors
    func execute<Value: Decodable>(
        _ type: Value.Type,
        request: URLRequest,
        endpoint: ApiEndpoint,
        timeout: TimeInterval,
        trustedSSLDomain: String?
    ) async throws -> Value {
        var context = RequestContext()
        let currentRequest = try await applyRequestInterceptors(request, endpoint: endpoint, context: &context)
        let httpClient = httpClientFactory(timeout, trustedSSLDomain)

        do {
            let (data, response) = try await httpClient.send(currentRequest)

            context.duration = Date().timeIntervalSince(context.startTime)

            let processed = try await applyResponseInterceptors(.success((data, response)), endpoint: endpoint, context: &context)
            let processedData: Data
            let processedResponse: URLResponse

            switch processed {
            case let .success(value):
                processedData = value.0
                processedResponse = value.1
            case let .failure(error):
                throw error
            }

            return try responseDecoder.decode(Value.self, from: processedData, response: processedResponse)
        } catch let error as SynologyError {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(error), endpoint: endpoint, context: &context)
            throw error
        } catch let urlError as URLError {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(urlError), endpoint: endpoint, context: &context)
            throw errorMapper.map(urlError)
        } catch {
            context.duration = Date().timeIntervalSince(context.startTime)
            _ = try await applyResponseInterceptors(.failure(error), endpoint: endpoint, context: &context)
            throw SynologyError.network(message: error.localizedDescription)
        }
    }

    /// 按正向顺序执行所有请求拦截器（adapt 阶段）
    /// Apply all request interceptors in forward order (adapt phase)
    private func applyRequestInterceptors(_ request: URLRequest, endpoint: ApiEndpoint, context: inout RequestContext) async throws -> URLRequest {
        var current = request
        for interceptor in interceptorsProvider() {
            if let contextAware = interceptor as? RequestInterceptorWithContext {
                current = try await contextAware.adapt(current, for: endpoint, context: &context)
            } else {
                current = try await interceptor.adapt(current, for: endpoint)
            }
        }
        return current
    }

    /// 按逆向顺序执行所有响应拦截器（process 阶段）
    /// Apply all response interceptors in reverse order (process phase)
    private func applyResponseInterceptors(_ result: Result<(Data, URLResponse), Error>, endpoint: ApiEndpoint, context: inout RequestContext) async throws -> Result<(Data, URLResponse), Error> {
        var current = result
        for interceptor in interceptorsProvider().reversed() {
            if let contextAware = interceptor as? RequestInterceptorWithContext {
                current = try await contextAware.process(current, for: endpoint, context: &context)
            } else {
                current = try await interceptor.process(current, for: endpoint)
            }
        }
        return current
    }
}
