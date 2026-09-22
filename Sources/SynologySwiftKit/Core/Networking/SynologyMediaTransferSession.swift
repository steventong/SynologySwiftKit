import Foundation
import SwiftHttpClient

public enum SynologyMediaTransferConfiguration: Sendable {
    case streaming
    case background(identifier: String)
}
public typealias SynologyMediaTransferTask = HTTPTransferTask

public protocol SynologyMediaTransferSessionDelegate: AnyObject {
    func mediaTransfer(_ task: SynologyMediaTransferTask, accept response: HTTPURLResponse) -> Bool
    func mediaTransfer(_ task: SynologyMediaTransferTask, received data: Data)
    /// Move the temporary file synchronously before this callback returns.
    func mediaTransfer(_ task: SynologyMediaTransferTask, downloadedFileAt location: URL)
    func mediaTransfer(_ task: SynologyMediaTransferTask, wrote bytes: Int64, total: Int64, expected: Int64)
    func mediaTransfer(_ task: SynologyMediaTransferTask, completedWith error: Error?)
    func mediaTransferSessionFinishedBackgroundEvents()
}
public extension SynologyMediaTransferSessionDelegate {
    func mediaTransfer(_ task: SynologyMediaTransferTask, accept response: HTTPURLResponse) -> Bool { true }
    func mediaTransfer(_ task: SynologyMediaTransferTask, received data: Data) {}
    func mediaTransfer(_ task: SynologyMediaTransferTask, downloadedFileAt location: URL) {}
    func mediaTransfer(_ task: SynologyMediaTransferTask, wrote bytes: Int64, total: Int64, expected: Int64) {}
    func mediaTransfer(_ task: SynologyMediaTransferTask, completedWith error: Error?) {}
    func mediaTransferSessionFinishedBackgroundEvents() {}
}

typealias MediaTransferFactory = (URLSessionConfiguration, OperationQueue, @escaping @Sendable (String) -> ServerTrustPolicy, any HTTPTransferSessionDelegate) -> HTTPTransferSession

func defaultMediaTransferFactory(_ configuration: URLSessionConfiguration, _ queue: OperationQueue,
                                 _ policy: @escaping @Sendable (String) -> ServerTrustPolicy,
                                 _ delegate: any HTTPTransferSessionDelegate) -> HTTPTransferSession {
    HTTPTransferSession(configuration: configuration, delegateQueue: queue, serverTrustPolicy: policy, delegate: delegate)
}

/// Transfers immutable media URLs using the SDK's approved certificate store.
/// Existing requests keep their original URL across login changes; callers retain each durable task's account identity.
public final class SynologyMediaTransferSession: HTTPTransferSessionDelegate {
    private weak var delegate: (any SynologyMediaTransferSessionDelegate)?
    private var transport: HTTPTransferSession!
    private let isBackground: Bool
    private let errorMapper = SynologyErrorMapper()
    // Callback access is serialized by the transfer delegate queue.
    private var responseFailures: [Int: Error] = [:]

    init(configuration: SynologyMediaTransferConfiguration, delegateQueue: OperationQueue,
         policy: @escaping @Sendable (String) -> ServerTrustPolicy,
         delegate: any SynologyMediaTransferSessionDelegate,
         factory: MediaTransferFactory = defaultMediaTransferFactory) {
        let native: URLSessionConfiguration
        switch configuration {
        case .streaming:
            isBackground = false
            native = .default
            native.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        case let .background(identifier):
            isBackground = true
            native = .background(withIdentifier: identifier)
            native.isDiscretionary = false
            native.httpMaximumConnectionsPerHost = 2
            native.sessionSendsLaunchEvents = true
        }
        self.delegate = delegate
        transport = factory(native, delegateQueue, policy, self)
    }

    public func streamTask(url: URL, range: Range<Int64>? = nil, headers: [String: String] = [:]) throws -> SynologyMediaTransferTask {
        guard !isBackground else { throw SynologyError.network(message: "Streaming requires a foreground transfer session") }
        var request = try mediaRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        if let range {
            guard range.lowerBound >= 0, range.lowerBound < range.upperBound else {
                throw SynologyError.network(message: "Invalid media byte range")
            }
            request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        } else { request.setValue("bytes=0-", forHTTPHeaderField: "Range") }
        return transport.dataTask(for: request)
    }
    public func downloadTask(url: URL) throws -> SynologyMediaTransferTask {
        let task = transport.downloadTask(for: try mediaRequest(url: url))
        task.priority = URLSessionTask.lowPriority
        return task
    }
    public func downloadTask(resumeData: Data) -> SynologyMediaTransferTask {
        let task = transport.downloadTask(resumeData: resumeData)
        task.priority = URLSessionTask.lowPriority
        return task
    }
    public func tasks(_ completion: @escaping @Sendable ([SynologyMediaTransferTask]) -> Void) { transport.tasks(completion) }
    public func invalidateAndCancel() { transport.invalidateAndCancel() }

    private func mediaRequest(url: URL) throws -> URLRequest {
        guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else {
            throw SynologyError.network(message: "Media transfers require an HTTP(S) URL")
        }
        return URLRequest(url: url)
    }
    private func acceptedResponse(_ response: URLResponse?, task: HTTPTransferTask) -> HTTPURLResponse? {
        guard let response = response as? HTTPURLResponse else {
            responseFailures[task.identifier] = SynologyError.network(message: "Invalid media response")
            return nil
        }
        guard (200..<300).contains(response.statusCode) else {
            responseFailures[task.identifier] = SynologyError.network(message: "Media request failed with HTTP status \(response.statusCode)")
            return nil
        }
        return response
    }
    public func transfer(_ task: HTTPTransferTask, accept response: URLResponse) -> Bool {
        guard let response = acceptedResponse(response, task: task) else { return false }
        return delegate?.mediaTransfer(task, accept: response) ?? false
    }
    public func transfer(_ task: HTTPTransferTask, received data: Data) { delegate?.mediaTransfer(task, received: data) }
    public func transfer(_ task: HTTPTransferTask, downloadedFileAt location: URL) {
        guard let response = acceptedResponse(task.response, task: task) else { return }
        do {
            let length = Int64(try location.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            guard length > 0, response.expectedContentLength <= 0 || response.expectedContentLength == length else {
                throw SynologyError.network(message: "Invalid media download size")
            }
            delegate?.mediaTransfer(task, downloadedFileAt: location)
        } catch { responseFailures[task.identifier] = error }
    }
    public func transfer(_ task: HTTPTransferTask, wrote bytes: Int64, total: Int64, expected: Int64) {
        delegate?.mediaTransfer(task, wrote: bytes, total: total, expected: expected)
    }
    public func transfer(_ task: HTTPTransferTask, completedWith error: Error?) {
        let failure = responseFailures.removeValue(forKey: task.identifier) ?? error
        delegate?.mediaTransfer(task, completedWith: failure.map { errorMapper.mapTransportError($0) })
    }
    public func transferSessionFinishedBackgroundEvents() { delegate?.mediaTransferSessionFinishedBackgroundEvents() }
}
