import Foundation
import SwiftHttpClient
import XCTest
@testable import SynologySwiftKit

final class MediaTransferSessionTests: XCTestCase {
    override func tearDown() { MediaProtocol.handler = nil; super.tearDown() }

    func testTransportUsesTheSameApprovedCertificateStoreAsAPIRequests() {
        let client = ApiClient(keyValueStorage: MockKeyValueStorage())
        client.approveServerCertificate(SynologyServerCertificate(host: "NAS.INVALID", subject: "NAS", sha256Fingerprint: "AA"))
        let probe = MediaProbe()
        var policy: (@Sendable (String) -> ServerTrustPolicy)?
        let transport = client.makeMediaTransferSession(configuration: .streaming, delegateQueue: queue(), delegate: probe, factory: { config, queue, resolver, delegate in
            policy = resolver
            return self.testTransport(config, queue, resolver, delegate)
        })
        XCTAssertEqual(policy?("nas.invalid"), .userApprovedCertificate(host: "nas.invalid", sha256Fingerprint: "AA"))
        XCTAssertEqual(policy?("other.invalid"), .userApprovedCertificate(host: "other.invalid", sha256Fingerprint: nil))
        client.approveServerCertificate(SynologyServerCertificate(host: "nas.invalid", subject: "NAS", sha256Fingerprint: "BB"))
        XCTAssertEqual(policy?("nas.invalid"), .userApprovedCertificate(host: "nas.invalid", sha256Fingerprint: "BB"))
        withExtendedLifetime(transport) {}
    }

    func testRangedMediaKeepsItsOriginalURLWhenTheLoginEndpointChanges() async throws {
        let done = expectation(description: "Original media completed")
        let client = ApiClient(keyValueStorage: MockKeyValueStorage())
        let probe = MediaProbe()
        let transport = client.makeMediaTransferSession(configuration: .streaming, delegateQueue: queue(), delegate: probe, factory: testTransport)
        let original = URL(string: "https://first.invalid/stream?_sid=original")!
        let task = try transport.streamTask(url: original, range: 10..<12)
        task.context = "first-account"
        client.updateConnection(type: .custom_domain, url: "https://second.invalid")
        MediaProtocol.handler = { request in
            XCTAssertEqual(request.url, original)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=10-11")
            return (206, Data([1, 2]))
        }
        probe.received = { received, data in
            XCTAssertTrue(received === task)
            XCTAssertEqual(received.context, "first-account")
            XCTAssertEqual(data, Data([1, 2]))
        }
        probe.completed = { _, error in XCTAssertNil(error); done.fulfill() }
        task.resume()
        await fulfillment(of: [done], timeout: 3)
        withExtendedLifetime(transport) {}
    }

    func testBackgroundConfigurationPreservesSystemIdentifierAndScheduling() throws {
        let client = ApiClient(keyValueStorage: MockKeyValueStorage())
        let probe = MediaProbe()
        let transport = client.makeMediaTransferSession(configuration: .background(identifier: "test.media.restore"), delegateQueue: queue(), delegate: probe,
            factory: { configuration, queue, policy, delegate in
                XCTAssertEqual(configuration.identifier, "test.media.restore")
                XCTAssertEqual(configuration.httpMaximumConnectionsPerHost, 2)
                XCTAssertFalse(configuration.isDiscretionary)
                XCTAssertTrue(configuration.sessionSendsLaunchEvents)
                return self.testTransport(configuration, queue, policy, delegate)
            })
        XCTAssertThrowsError(try transport.streamTask(url: URL(string: "https://nas.invalid/song")!))
        let task = try transport.downloadTask(url: URL(string: "https://nas.invalid/song")!)
        task.context = "persisted-owner"
        XCTAssertEqual(task.context, "persisted-owner")
        XCTAssertEqual(task.priority, URLSessionTask.lowPriority)
        task.cancel()
    }

    func testInvalidRangeAndNonHTTPResourceNeverStartATransfer() throws {
        let client = ApiClient(keyValueStorage: MockKeyValueStorage())
        let probe = MediaProbe()
        let transport = client.makeMediaTransferSession(configuration: .streaming, delegateQueue: queue(), delegate: probe, factory: testTransport)
        XCTAssertThrowsError(try transport.streamTask(url: URL(string: "https://nas.invalid/song")!, range: -1..<10))
        XCTAssertThrowsError(try transport.streamTask(url: URL(string: "https://nas.invalid/song")!, range: 0..<0))
        XCTAssertThrowsError(try transport.downloadTask(url: URL(fileURLWithPath: "/tmp/private")))
    }

    func testNonSuccessHTTPResponseIsMappedBeforeAnyStreamDataOrFileIsDelivered() async throws {
        for fileDownload in [false, true] {
            let done = expectation(description: "Rejected media response")
            let client = ApiClient(keyValueStorage: MockKeyValueStorage())
            let probe = MediaProbe()
            let transport = client.makeMediaTransferSession(configuration: .streaming, delegateQueue: queue(), delegate: probe, factory: testTransport)
            MediaProtocol.handler = { _ in (403, Data([1, 2])) }
            probe.accepted = { _, _ in XCTFail("Invalid HTTP response reached media consumer"); return true }
            probe.received = { _, _ in XCTFail("Invalid response body") }
            probe.downloaded = { _, _ in XCTFail("Invalid response file") }
            probe.completed = { _, error in
                guard let error, case let SynologyError.network(message) = error else { return XCTFail("Expected SDK transport error") }
                XCTAssertTrue(message.contains("403"))
                done.fulfill()
            }
            let url = URL(string: "https://nas.invalid/denied")!
            let task = try fileDownload ? transport.downloadTask(url: url) : transport.streamTask(url: url)
            task.resume()
            await fulfillment(of: [done], timeout: 3)
            withExtendedLifetime(transport) {}
        }
    }

    func testTransportErrorMappingPreservesCancellationAndCertificateIdentity() {
        let mapper = SynologyErrorMapper()
        XCTAssertTrue(mapper.mapTransportError(URLError(.cancelled)) is CancellationError)
        let certificate = ServerCertificateInfo(host: "nas.invalid", subject: "NAS", sha256Fingerprint: "AA")
        guard case let SynologyError.serverCertificateUntrusted(value) = mapper.mapTransportError(HTTPClientError.serverCertificateUntrusted(certificate)) else {
            return XCTFail("Certificate mapping")
        }
        XCTAssertEqual(value.host, certificate.host)
        XCTAssertEqual(value.sha256Fingerprint, certificate.sha256Fingerprint)
    }

    func testEmptyMediaDownloadIsRejectedBeforePersistence() async throws {
        let done = expectation(description: "Empty media rejected")
        let client = ApiClient(keyValueStorage: MockKeyValueStorage())
        let probe = MediaProbe()
        let transport = client.makeMediaTransferSession(configuration: .streaming, delegateQueue: queue(), delegate: probe, factory: testTransport)
        MediaProtocol.handler = { _ in (200, Data()) }
        probe.downloaded = { _, _ in XCTFail("Empty file must not reach persistence") }
        probe.completed = { _, error in XCTAssertNotNil(error as? SynologyError); done.fulfill() }
        try transport.downloadTask(url: URL(string: "https://nas.invalid/empty")!).resume()
        await fulfillment(of: [done], timeout: 3)
        withExtendedLifetime(transport) {}
    }

    private func queue() -> OperationQueue { let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1; return queue }
    private func testTransport(_ ignoredConfiguration: URLSessionConfiguration, _ queue: OperationQueue,
                               _ policy: @escaping @Sendable (String) -> ServerTrustPolicy, _ delegate: any HTTPTransferSessionDelegate) -> HTTPTransferSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaProtocol.self]
        return HTTPTransferSession(configuration: config, delegateQueue: queue, serverTrustPolicy: policy, delegate: delegate)
    }
}

private final class MediaProbe: SynologyMediaTransferSessionDelegate {
    var accepted: (SynologyMediaTransferTask, HTTPURLResponse) -> Bool = { _, _ in true }
    var received: (SynologyMediaTransferTask, Data) -> Void = { _, _ in }
    var downloaded: (SynologyMediaTransferTask, URL) -> Void = { _, _ in }
    var completed: (SynologyMediaTransferTask, Error?) -> Void = { _, _ in }
    func mediaTransfer(_ task: SynologyMediaTransferTask, accept response: HTTPURLResponse) -> Bool { accepted(task, response) }
    func mediaTransfer(_ task: SynologyMediaTransferTask, received data: Data) { received(task, data) }
    func mediaTransfer(_ task: SynologyMediaTransferTask, downloadedFileAt location: URL) { downloaded(task, location) }
    func mediaTransfer(_ task: SynologyMediaTransferTask, completedWith error: Error?) { completed(task, error) }
}
private final class MediaProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let (status, data) = Self.handler?(request) else { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": String(data.count)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
