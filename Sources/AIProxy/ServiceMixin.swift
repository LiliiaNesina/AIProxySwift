//
//  ServiceMixin.swift
//  AIProxy
//
//  Created by Lou Zell on 4/24/25.
//

import Foundation

@AIProxyActor protocol ServiceMixin: Sendable {
    var urlSession: URLSession { get }
}

extension ServiceMixin {
    @AIProxyActor func makeRequestAndDeserializeResponse<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let response: AIProxyResponseWithHeaders<T> = try await self.makeRequestAndDeserializeResponseWithMetadata(request)
        return response.body
    }

    @AIProxyActor func makeRequestAndDeserializeResponseWithMetadata<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AIProxyResponseWithHeaders<T> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }
        let (data, httpResponse) = try await BackgroundNetworker.makeRequestAndWaitForData(
            self.urlSession,
            request
        )
        if AIProxy.printResponseBodies {
            printBufferedResponseBody(data)
        }
        return AIProxyResponseWithHeaders(
            body: try T.deserialize(from: data),
            headers: httpResponse.readableHeaders
        )
    }

    @AIProxyActor func makeRequestAndDeserializeStreamingChunks<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AsyncThrowingStream<T, Error> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }

        let (asyncBytes, _) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession,
            request
        )

        let sequence = asyncBytes.lines.compactMap { @AIProxyActor [shouldPrint = AIProxy.printResponseBodies] (line: String) -> T? in
            if shouldPrint {
                printStreamingResponseChunk(line)
            }
            return T.deserialize(fromLine: line)
        }

        // This swift juggling is because I don't want the return types of our API to be
        // something like: AsyncCompactMapSequence<AsyncLineSequence<URLSession.AsyncBytes>, OpenAIChatCompletionChunk>
        //
        // So instead I manually map it to an AsyncStream with a nice signature of AsyncThrowingStream<OpenAIChatCompletionChunk, Error>.
        return AsyncThrowingStream { @AIProxyActor continuation in
            let task = Task {
                do {
                    for try await item in sequence {
                        if Task.isCancelled {
                            break
                        }
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Responses streams must not silently drop a malformed event or treat a
    /// severed connection as a successful answer. The generic SSE decoder is
    /// intentionally tolerant for other providers, so Responses uses this
    /// stricter typed path.
    @AIProxyActor func makeRequestAndDeserializeOpenAIResponseEvents(
        _ request: URLRequest
    ) async throws -> AsyncThrowingStream<OpenAIResponseStreamingEvent, Error> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }
        let (bytes, response) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession, request
        )
        guard response.value(forHTTPHeaderField: "Content-Type")?
            .lowercased().contains("text/event-stream") == true else {
            throw AIProxyError.assertion("Expected a Responses event stream")
        }

        return AsyncThrowingStream { @AIProxyActor continuation in
            let task = Task {
                do {
                    var frame = ""
                    var terminal = false
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if AIProxy.printResponseBodies {
                            printStreamingResponseChunk(line)
                        }
                        if line.isEmpty {
                            guard !frame.isEmpty else { continue }
                            if frame == "[DONE]" {
                                frame = ""
                                continue
                            }
                            let data = Data(frame.utf8)
                            frame = ""
                            let envelope = try JSONDecoder().decode(OpenAIResponseEventEnvelope.self, from: data)
                            // A future additive event should not break older SDKs.
                            guard let type = OpenAIResponseStreamEventType(rawValue: envelope.type) else { continue }
                            let event = try JSONDecoder().decode(OpenAIResponseStreamingEvent.self, from: data)
                            switch type {
                            case .responseCompleted, .responseFailed, .responseIncomplete, .error:
                                terminal = true
                            default:
                                break
                            }
                            continuation.yield(event)
                        } else if line.hasPrefix("data:") {
                            var value = line.dropFirst(5)
                            if value.first == " " { value = value.dropFirst() }
                            guard frame.utf8.count + value.utf8.count < 32 * 1_024 * 1_024 else {
                                throw AIProxyError.assertion("Responses event exceeds 32 MiB")
                            }
                            if !frame.isEmpty { frame += "\n" }
                            frame += value
                        }
                    }
                    guard terminal && frame.isEmpty else {
                        throw AIProxyError.assertion("Responses stream ended before a terminal event")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Agent streams are SSE, with a required terminal response. Do not use the
    /// generic tolerant decoder here: a dropped terminal event would turn a
    /// truncated, charged search into an apparently successful empty answer.
    @AIProxyActor func makeRequestAndDeserializePerplexityAgentEvents(
        _ request: URLRequest
    ) async throws -> AsyncThrowingStream<PerplexityAgentStreamingEvent, Error> {
        if AIProxy.printRequestBodies { printRequestBody(request) }
        let (bytes, response) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession, request
        )
        guard response.value(forHTTPHeaderField: "Content-Type")?
            .lowercased().contains("text/event-stream") == true else {
            throw AIProxyError.assertion("Expected a Perplexity Agent event stream")
        }
        return AsyncThrowingStream { @AIProxyActor continuation in
            let task = Task {
                do {
                    var frame = ""
                    var completed = false
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if AIProxy.printResponseBodies { printStreamingResponseChunk(line) }
                        if line.isEmpty {
                            guard !frame.isEmpty else { continue }
                            if frame == "[DONE]" { frame = ""; continue }
                            let event = try JSONDecoder().decode(
                                PerplexityAgentStreamingEvent.self, from: Data(frame.utf8)
                            )
                            frame = ""
                            switch event {
                            case .completed(let response):
                                guard response.status == "completed" else {
                                    throw AIProxyError.assertion("Perplexity Agent did not complete")
                                }
                                completed = true
                            case .failed:
                                throw AIProxyError.assertion("Perplexity Agent failed")
                            default:
                                break
                            }
                            continuation.yield(event)
                        } else if line.hasPrefix("data:") {
                            var value = line.dropFirst(5)
                            if value.first == " " { value = value.dropFirst() }
                            guard frame.utf8.count + value.utf8.count < 32 * 1_024 * 1_024 else {
                                throw AIProxyError.assertion("Perplexity Agent event exceeds 32 MiB")
                            }
                            if !frame.isEmpty { frame += "\n" }
                            frame += value
                        }
                    }
                    guard completed && frame.isEmpty else {
                        throw AIProxyError.assertion("Perplexity Agent stream ended before completion")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Deserializes streaming NDJSON (newline-delimited JSON) chunks.
    /// Unlike `makeRequestAndDeserializeStreamingChunks`, this method does not expect
    /// SSE-style "data: " prefixes. Each line is treated as raw JSON.
    @AIProxyActor func makeRequestAndDeserializeNDJSONChunks<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AsyncThrowingStream<T, Error> {
        let response: AIProxyChunkStreamResponse<T> = try await self.makeRequestAndDeserializeNDJSONChunksWithMetadata(request)
        return response.stream
    }

    @AIProxyActor func makeRequestAndDeserializeNDJSONChunksWithMetadata<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AIProxyChunkStreamResponse<T> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }

        let (asyncBytes, httpResponse) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession,
            request
        )

        let stream = AsyncThrowingStream<T, Error> { @AIProxyActor continuation in
            let task = Task {
                do {
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            break
                        }
                        if AIProxy.printResponseBodies {
                            printStreamingResponseChunk(line)
                        }
                        guard !line.isEmpty else { continue }
                        guard let data = line.data(using: .utf8) else { continue }
                        do {
                            let deserialized = try T.deserialize(from: data)
                            continuation.yield(deserialized)
                        } catch {
                            logIf(.warning)?.warning(
                                """
                                AIProxy: Could not deserialize \(T.self) from NDJSON line: \(line)
                                Decodable error: \(error)
                                """
                            )
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        return AIProxyChunkStreamResponse(
            headers: httpResponse.readableHeaders,
            stream: stream
        )
    }
}

private struct OpenAIResponseEventEnvelope: Decodable {
    let type: String
}

private extension URLRequest {
    nonisolated var readableURL: String {
        return self.url?.absoluteString ?? ""
    }

    nonisolated var readableBody: String {
        guard let body = self.httpBody else {
            return "None"
        }

        return String(data: body, encoding: .utf8) ?? "None"
    }
}

nonisolated private func printRequestBody(_ request: URLRequest) {
    logIf(.debug)?.debug(
        """
        Making a request to \(request.readableURL)
        with request body:
        \(request.readableBody)
        """
    )
}

nonisolated private func printBufferedResponseBody(_ data: Data) {
    logIf(.debug)?.debug(
        """
        Received response body:
        \(String(data: data, encoding: .utf8) ?? "")
        """
    )
}

nonisolated private func printStreamingResponseChunk(_ chunk: String) {
    logIf(.debug)?.debug(
        """
        Received streaming response chunk:
        \(chunk)
        """
    )
}

extension HTTPURLResponse {
    var readableHeaders: [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in self.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }
}
