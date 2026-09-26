//
//  PerplexityAgentResponseBody.swift
//  AIProxy
//
//  Created for Perplexity Agent API (`POST /v1/agent`).
//

import Foundation

/// Response from the Perplexity Agent API. The `output` array carries
/// the assistant's final text (`type: "message"`), interleaved tool
/// outputs (`type: "search_results"`, `type: "fetch_url_results"`),
/// and any other agent-runtime artifacts.
///
/// Reference: https://docs.perplexity.ai/docs/agent-api/quickstart
public struct PerplexityAgentResponseBody: Decodable, Sendable {
    public let id: String?
    public let status: String?
    public let model: String?
    public let output: [OutputItem]?
    public let usage: Usage?
    public let createdAt: TimeInterval?
    public let completedAt: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case model
        case output
        case usage
        case createdAt   = "created_at"
        case completedAt = "completed_at"
    }

    public struct OutputItem: Decodable, Sendable {
        /// Possible values:
        /// - `"message"` — assistant's final answer (with `content` blocks)
        /// - `"people_search_results"` — output of the `people_search` tool
        /// - `"web_search_results"` — output of the `web_search` tool
        /// - `"fetch_url_results"` — output of the `fetch_url` tool
        public let type: String?
        public let role: String?
        public let status: String?
        public let id: String?
        public let content: [ContentBlock]?
        public let results: [SearchResult]?
        public let queries: [String]?
        public let url: String?
        public let title: String?

        private enum CodingKeys: String, CodingKey {
            case type, role, status, id, content, results, queries, url, title
        }
    }

    public struct ContentBlock: Decodable, Sendable {
        /// e.g. `"output_text"` for assistant message content.
        public let type: String?
        public let text: String?
        public let annotations: [Annotation]?
    }

    public struct Annotation: Decodable, Sendable {
        public let type: String?
        public let url: String?
        public let title: String?
        public let snippet: String?
        public let startIndex: Int?
        public let endIndex: Int?

        private enum CodingKeys: String, CodingKey {
            case type, url, title, snippet
            case startIndex = "start_index"
            case endIndex   = "end_index"
        }
    }

    public struct SearchResult: Decodable, Sendable {
        public let id: Int?
        public let url: String?
        public let title: String?
        public let snippet: String?
        /// Per-result origin tag from the agent, e.g. `"web"` or
        /// `"people_search"`. Tells you which tool produced the hit
        /// when multiple are active.
        public let source: String?
        /// `YYYY-MM-DD` timestamp of when the source was last indexed
        /// by Perplexity (when the agent returns it — primarily on
        /// `people_search` hits).
        public let lastUpdated: String?
        public let date: String?
        public let publisher: String?
        public let author: String?
        /// Profile-shaped fields the `people_search` tool returns.
        public let name: String?
        public let role: String?
        public let company: String?
        public let location: String?
        public let socialProfiles: [SocialProfile]?

        private enum CodingKeys: String, CodingKey {
            case id, url, title, snippet, source
            case lastUpdated = "last_updated"
            case date, publisher, author
            case name, role, company, location
            case socialProfiles = "social_profiles"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? values.decode(Int.self, forKey: .id))
                ?? (try? values.decode(String.self, forKey: .id)).flatMap { raw in
                    if let plain = Int(raw) { return plain }
                    let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
                    guard parts.count == 2,
                          ["web", "people_search"].contains(String(parts[0]))
                    else { return nil }
                    return Int(parts[1])
                }
            url = try values.decodeIfPresent(String.self, forKey: .url)
            title = try values.decodeIfPresent(String.self, forKey: .title)
            snippet = try values.decodeIfPresent(String.self, forKey: .snippet)
            source = try values.decodeIfPresent(String.self, forKey: .source)
            lastUpdated = try values.decodeIfPresent(String.self, forKey: .lastUpdated)
            date = try values.decodeIfPresent(String.self, forKey: .date)
            publisher = try values.decodeIfPresent(String.self, forKey: .publisher)
            author = try values.decodeIfPresent(String.self, forKey: .author)
            name = try values.decodeIfPresent(String.self, forKey: .name)
            role = try values.decodeIfPresent(String.self, forKey: .role)
            company = try values.decodeIfPresent(String.self, forKey: .company)
            location = try values.decodeIfPresent(String.self, forKey: .location)
            socialProfiles = try values.decodeIfPresent([SocialProfile].self, forKey: .socialProfiles)
        }
    }

    public struct SocialProfile: Decodable, Sendable {
        public let platform: String?
        public let url: String?
        public let handle: String?
    }

    public struct Usage: Decodable, Sendable {
        public let totalTokens: Int?
        public let inputTokens: Int?
        public let outputTokens: Int?
        public let inputTokensDetails: TokenDetails?
        public let outputTokensDetails: TokenDetails?
        public let cost: Cost?
        /// Per-tool invocation counts, e.g.
        /// `{"search_people": {"invocation": 1}}`. Useful when you
        /// bill end-users per tool call rather than per request.
        public let toolCallsDetails: [String: ToolInvocation]?

        private enum CodingKeys: String, CodingKey {
            case totalTokens         = "total_tokens"
            case inputTokens         = "input_tokens"
            case outputTokens        = "output_tokens"
            case inputTokensDetails  = "input_tokens_details"
            case outputTokensDetails = "output_tokens_details"
            case cost
            case toolCallsDetails    = "tool_calls_details"
        }
    }

    public struct TokenDetails: Decodable, Sendable {
        public let cachedTokens: Int?
        public let reasoningTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case cachedTokens    = "cached_tokens"
            case reasoningTokens = "reasoning_tokens"
        }
    }

    public struct ToolInvocation: Decodable, Sendable {
        public let invocation: Int?
    }

    public struct Cost: Decodable, Sendable {
        public let currency: String?
        public let totalCost: Double?
        public let inputCost: Double?
        public let outputCost: Double?
        public let toolCallsCost: Double?

        private enum CodingKeys: String, CodingKey {
            case currency
            case totalCost     = "total_cost"
            case inputCost     = "input_cost"
            case outputCost    = "output_cost"
            case toolCallsCost = "tool_calls_cost"
        }
    }
}

/// Convenience accessors for the most common usage pattern: grab the
/// concatenated assistant text + flat list of all search-result URLs.
public extension PerplexityAgentResponseBody {
    /// Concatenated text from every `type: "message"` output item.
    var assistantText: String {
        (output ?? [])
            .filter { $0.type == "message" }
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n\n")
    }

    /// Flat list of every search result the agent surfaced across all
    /// tool invocations. Useful for building a "sources" UI strip
    /// regardless of which tool (people_search / web_search / etc.)
    /// produced them.
    var allSearchResults: [SearchResult] {
        (output ?? [])
            .flatMap { $0.results ?? [] }
    }
}
