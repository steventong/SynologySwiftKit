import Foundation

final class ApiRequestExecutor {
    private let httpClient: HTTPClientProtocol
    private let interceptorsProvider: () -> [RequestInterceptor]
    private let responseDecoder: ApiResponseDecoder
    private let errorMapper: SynologyErrorMapper

    init(
        httpClient: HTTPClientProtocol,
        interceptorsProvider: @escaping () -> [RequestInterceptor],
        responseDecoder: ApiResponseDecoder = ApiResponseDecoder(),
        errorMapper: SynologyErrorMapper = SynologyErrorMapper()
    ) {
        self.httpClient = httpClient
        self.interceptorsProvider = interceptorsProvider
        self.responseDecoder = responseDecoder
        self.errorMapper = errorMapper
    }

    func execute<Value: Decodable>(
        _ type: Value.Type,
        request: URLRequest,
        endpoint: ApiEndpoint,
        timeout: TimeInterval,
        trustedSSLDomain: String?
    ) async throws -> Value {
        var context = RequestContext()
        let currentRequest = try await applyRequestInterceptors(request, endpoint: endpoint, context: &context)

        do {
            let (data, response) = try await httpClient.send(currentRequest, timeout: timeout, trustedSSLDomain: trustedSSLDomain)

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
