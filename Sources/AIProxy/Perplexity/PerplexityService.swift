//
//  PerplexityService.swift
//
//
//  Created by Lou Zell on 12/19/24.
//

import Foundation

@AIProxyActor public protocol PerplexityService: Sendable {
    /// Initiates a non-streaming chat completion request to Perplexity
    ///
    /// - Parameters:
    ///   - body: The chat completion request body. See this reference:
    ///   https://platform.openai.com/docs/api-reference/chat/object
    ///
    /// - Returns: A ChatCompletionResponse
    func chatCompletionRequest(
        body: PerplexityChatCompletionRequestBody
    ) async throws -> PerplexityChatCompletionResponseBody

    /// Initiates a streaming chat completion request to Perplexity.
    ///
    /// - Parameters:
    ///
    ///   - body: The chat completion request body. See this reference:
    ///   https://platform.openai.com/docs/api-reference/chat/object
    ///
    /// - Returns: An async sequence of completion chunks.
    func streamingChatCompletionRequest(
        body: PerplexityChatCompletionRequestBody
    ) async throws -> AsyncThrowingStream<PerplexityChatCompletionResponseBody, Error>

    /// Calls Perplexity's Agent API (`POST /v1/agent`).
    ///
    /// Unlike the Chat Completions surface, the Agent API takes a
    /// single `input` string plus an explicit `tools` array
    /// (`web_search`, `people_search`, ...). The runtime decides when
    /// to invoke each tool and returns a structured `output` array
    /// containing the assistant's final text plus any tool artifacts.
    ///
    /// - Parameters:
    ///   - body: The agent request body. See `PerplexityAgentRequestBody`.
    ///   - secondsToWait: URL request timeout.
    ///
    /// - Returns: A `PerplexityAgentResponseBody`.
    func agentRequest(
        body: PerplexityAgentRequestBody,
        secondsToWait: UInt
    ) async throws -> PerplexityAgentResponseBody

    /// Streams typed Agent events and requires a completed terminal response.
    func streamingAgentRequest(
        body: PerplexityAgentRequestBody,
        secondsToWait: UInt
    ) async throws -> AsyncThrowingStream<PerplexityAgentStreamingEvent, Error>
}
