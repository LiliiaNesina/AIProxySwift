//
//  PerplexityDirectService.swift
//
//
//  Created by Lou Zell on 12/19/24.
//

import Foundation

@AIProxyActor final class PerplexityDirectService: PerplexityService, DirectService, Sendable {
    private let unprotectedAPIKey: String
    private let baseURL: String
    private let additionalHeaders: [String: String]
    private let authHeader: (key: String, value: String)

    /// This initializer is not public on purpose.
    /// Customers are expected to use the factory `AIProxy.perplexityDirectService` defined in AIProxy.swift
    nonisolated init(
        unprotectedAPIKey: String,
        baseURL: String? = nil,
        additionalHeaders: [String: String] = [:],
        unprotectedAuthHeader: (key: String, value: String)? = nil
    ) {
        self.unprotectedAPIKey = unprotectedAPIKey
        self.baseURL = baseURL ?? "https://api.perplexity.ai"
        self.additionalHeaders = additionalHeaders
        self.authHeader = unprotectedAuthHeader ?? (key: "Authorization", value: "Bearer \(unprotectedAPIKey)")
    }

    /// Caller-supplied headers attached to every request, with the auth header
    /// (default or overridden) taking precedence over extras.
    private nonisolated var requestHeaders: [String: String] {
        self.additionalHeaders.merging(
            [self.authHeader.key: self.authHeader.value]
        ) { _, auth in auth }
    }

    /// Initiates a non-streaming chat completion request to Perplexity
    ///
    /// - Parameters:
    ///   - body: The chat completion request body. See this reference:
    ///   https://platform.openai.com/docs/api-reference/chat/object
    ///
    /// - Returns: A ChatCompletionResponse
    public func chatCompletionRequest(
        body: PerplexityChatCompletionRequestBody
    ) async throws -> PerplexityChatCompletionResponseBody {
        var body = body
        body.stream = false
        let request = try AIProxyURLRequest.createDirect(
            baseURL: self.baseURL,
            path: "/chat/completions",
            body: try body.serialize(),
            verb: .post,
            secondsToWait: 60,
            contentType: "application/json",
            additionalHeaders: self.requestHeaders
        )
        return try await self.makeRequestAndDeserializeResponse(request)
    }

    /// Initiates a streaming chat completion request to Perplexity.
    ///
    /// - Parameters:
    ///
    ///   - body: The chat completion request body. See this reference:
    ///   https://platform.openai.com/docs/api-reference/chat/object
    ///
    /// - Returns: An async sequence of completion chunks.
    public func streamingChatCompletionRequest(
        body: PerplexityChatCompletionRequestBody
    ) async throws -> AsyncThrowingStream<PerplexityChatCompletionResponseBody, Error> {
        var body = body
        body.stream = true
        let request = try AIProxyURLRequest.createDirect(
            baseURL: self.baseURL,
            path: "/chat/completions",
            body:  try body.serialize(),
            verb: .post,
            secondsToWait: 60,
            contentType: "application/json",
            additionalHeaders: self.requestHeaders
        )
        return try await self.makeRequestAndDeserializeStreamingChunks(request)
    }

    /// Calls Perplexity's Agent API (`POST /v1/agent`).
    public func agentRequest(
        body: PerplexityAgentRequestBody,
        secondsToWait: UInt = 120
    ) async throws -> PerplexityAgentResponseBody {
        var body = body
        body.stream = false
        let request = try AIProxyURLRequest.createDirect(
            baseURL: self.baseURL,
            path: "/v1/agent",
            body: try JSONEncoder.aiproxyPerplexityDirect.encode(body),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "application/json",
            additionalHeaders: self.requestHeaders
        )
        return try await self.makeRequestAndDeserializeResponse(request)
    }

    public func streamingAgentRequest(
        body: PerplexityAgentRequestBody,
        secondsToWait: UInt = 300
    ) async throws -> AsyncThrowingStream<PerplexityAgentStreamingEvent, Error> {
        var body = body
        body.stream = true
        let request = try AIProxyURLRequest.createDirect(
            baseURL: self.baseURL,
            path: "/v1/agent",
            body: try JSONEncoder.aiproxyPerplexityDirect.encode(body),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "application/json",
            additionalHeaders: self.requestHeaders
        )
        return try await self.makeRequestAndDeserializePerplexityAgentEvents(request)
    }
}

private extension JSONEncoder {
    static let aiproxyPerplexityDirect: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}
