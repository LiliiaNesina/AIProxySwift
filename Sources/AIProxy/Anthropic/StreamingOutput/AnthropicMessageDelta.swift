//
//  AnthropicMessageDelta.swift
//  AIProxy
//
//  Created by Lou Zell on 12/12/25.
//

/// Represents Anthropic's `message_delta` streaming event::
/// https://platform.claude.com/docs/en/build-with-claude/streaming
public struct AnthropicMessageDelta: Decodable, Sendable {
    public let type = "message_delta"
    public let delta: Delta

    /// Cumulative token counts for the message. Only `output_tokens` is reliably present;
    /// see `AnthropicMessageDeltaUsage`.
    public let usage: AnthropicMessageDeltaUsage?

    private enum CodingKeys: String, CodingKey {
        case delta
        case usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delta = try container.decode(Delta.self, forKey: .delta)
        // Usage is informational. An unexpected shape must never cost the event its
        // `stop_reason`, and a strict decode here fails the whole stream for callers
        // that treat an undecodable event as fatal.
        self.usage = try? container.decodeIfPresent(AnthropicMessageDeltaUsage.self, forKey: .usage)
    }
}

extension AnthropicMessageDelta {
    public struct Delta: Decodable, Sendable {
        public let stopReason: AnthropicStopReason?
        public let stopSequence: String?

        private enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }
    }
}
