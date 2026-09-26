import Foundation
import XCTest
@testable import AIProxy

final class SSELineReaderTests: XCTestCase {
    func testResponsesAndAgentStreamsReachTerminalEvent() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SSEURLProtocol.self]
        let service = SSETestService(urlSession: URLSession(configuration: configuration))

        let responses = try await service.makeRequestAndDeserializeOpenAIResponseEvents(
            URLRequest(url: URL(string: "https://sse.test/responses")!)
        )
        var responseCompleted = false
        for try await event in responses {
            if case .responseCompleted = event { responseCompleted = true }
        }
        XCTAssertTrue(responseCompleted)

        let agent = try await service.makeRequestAndDeserializePerplexityAgentEvents(
            URLRequest(url: URL(string: "https://sse.test/agent")!)
        )
        var agentCompleted = false
        for try await event in agent {
            if case .completed = event { agentCompleted = true }
        }
        XCTAssertTrue(agentCompleted)
    }

    func testPreservesEventDelimitersAndFinalBlankLine() async throws {
        let wire = "event: response.created\r\ndata: {\"type\":\"response.created\"}\r\n\r\n"
            + "event: response.completed\ndata: {\"type\":\"response.completed\"}\n\n"
        let bytes = AsyncStream<UInt8> { continuation in
            for byte in wire.utf8 { continuation.yield(byte) }
            continuation.finish()
        }
        var lines: [String] = []
        try await forEachSSELine(in: bytes) { lines.append($0) }
        XCTAssertEqual(lines, [
            "event: response.created",
            "data: {\"type\":\"response.created\"}",
            "",
            "event: response.completed",
            "data: {\"type\":\"response.completed\"}",
            "",
        ])
    }

    func testEmitsUnterminatedLastLineForTruncationCheck() async throws {
        let bytes = AsyncStream<UInt8> { continuation in
            for byte in "data: incomplete".utf8 { continuation.yield(byte) }
            continuation.finish()
        }
        var lines: [String] = []
        try await forEachSSELine(in: bytes) { lines.append($0) }
        XCTAssertEqual(lines, ["data: incomplete"])
    }
}

@AIProxyActor private struct SSETestService: ServiceMixin {
    let urlSession: URLSession
}

private final class SSEURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sse.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
              ) else { return }
        let json = url.path == "/agent"
            ? #"{"type":"response.completed","response":{"status":"completed","output":[]}}"#
            : #"{"type":"response.completed","sequence_number":2,"response":{"id":"resp_gpt6","created_at":1,"model":"gpt-6-luna","status":"completed","output":[],"reasoning":{"effort":"max","summary":"auto"},"store":false}}"#
        let wire = "event: response.completed\ndata: \(json)\n\n"
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(wire.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
