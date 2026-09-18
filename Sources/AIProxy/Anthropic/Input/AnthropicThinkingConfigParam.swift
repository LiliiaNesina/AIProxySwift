//
//  AnthropicThinkingConfigParam.swift
//  AIProxy
//
//  Created by Lou Zell on 12/10/25.
//

import Foundation

/// Configuration for Claude's thinking.
///
/// When thinking is on, responses include `thinking` content blocks before the final answer, and
/// the thinking tokens count towards your `max_tokens` limit.
///
/// - `adaptive`: Claude decides per request whether and how deeply to think; steer the depth with
///   `output_config.effort`. The only on-mode for Claude 5 models (`budget_tokens` is rejected there).
/// - `enabled(budgetTokens:)`: the manual budget used by models before adaptive thinking, e.g.
///   Claude Haiku 4.5. Requires at least 1,024 tokens and less than `max_tokens`.
///
/// See [adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking) and
/// [extended thinking](https://platform.claude.com/docs/en/build-with-claude/extended-thinking).
nonisolated public enum AnthropicThinkingConfigParam: Encodable, Sendable {
    /// Enable extended thinking with a token budget.
    ///
    /// - Parameter budgetTokens: Determines how many tokens Claude can use for its internal
    ///   reasoning process. Larger budgets can enable more thorough analysis for complex problems,
    ///   improving response quality. Must be ≥1024 and less than `max_tokens`.
    case enabled(budgetTokens: Int)

    /// Let Claude decide whether and how much to think (Claude 5 models).
    case adaptive

    /// Disable thinking.
    case disabled

    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .enabled(let budgetTokens):
            try container.encode("enabled", forKey: .type)
            try container.encode(budgetTokens, forKey: .budgetTokens)
        case .adaptive:
            try container.encode("adaptive", forKey: .type)
        case .disabled:
            try container.encode("disabled", forKey: .type)
        }
    }
}
