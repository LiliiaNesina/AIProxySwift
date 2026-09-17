//
//  AnthropicOutputConfig.swift
//

import Foundation

/// The `output_config` request field: how much effort Claude 4.5+ spends
/// across thinking, tool calls and the answer itself. Independent of the
/// `thinking` setting.
nonisolated public struct AnthropicOutputConfig: Encodable, Sendable {
    /// `low`, `medium`, `high`, `xhigh` or `max` — the model's documented set.
    public let effort: String

    public init(effort: String) {
        self.effort = effort
    }
}
