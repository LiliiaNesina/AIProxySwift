//
//  AnthropicMessageDeltaUsage.swift
//  AIProxy
//

/// Token counts carried by a `message_delta` streaming event.
///
/// Unlike the `usage` of a complete message, every field here is optional: Anthropic's
/// `MessageDeltaUsage` schema marks all but `output_tokens` as nullable, and the event often
/// carries `output_tokens` alone, e.g. `"usage": {"output_tokens": 15}`.
/// https://platform.claude.com/docs/en/build-with-claude/streaming
public struct AnthropicMessageDeltaUsage: Decodable, Sendable {
    /// The cumulative number of input tokens, when reported.
    public let inputTokens: Int?

    /// The cumulative number of output tokens, thinking included.
    public let outputTokens: Int?

    /// The cumulative number of input tokens used to create the cache entry, when reported.
    public let cacheCreationInputTokens: Int?

    /// The cumulative number of input tokens read from the cache, when reported.
    public let cacheReadInputTokens: Int?

    /// The number of server tool requests, when reported.
    public let serverToolUse: AnthropicServerToolUsage?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case serverToolUse = "server_tool_use"
    }
}
