//
//  PerplexityAgentRequestBody.swift
//  AIProxy
//
//  Created for Perplexity Agent API (`POST /v1/agent`).
//

import Foundation

/// Request body for Perplexity's Agent API. Different shape than the
/// Chat Completions API: takes an `input` (plain text query OR a
/// structured array of role-tagged messages with typed content blocks)
/// plus an explicit `tools` array. The agent runtime decides when to
/// invoke each tool (`web_search`, `people_search`, `finance_search`,
/// ...) and returns a structured `output` array.
///
/// Multimodal: pass `Input.messages([...])` with `ContentBlock`s
/// containing `.inputText` and `.inputImage` to send an image (data
/// URI or remote URL) alongside the query. Vision-capable models only
/// (e.g. `openai/gpt-5-mini`).
///
/// Reference: https://docs.perplexity.ai/docs/agent-api/quickstart
public struct PerplexityAgentRequestBody: Encodable, Sendable {
    public let model: String
    public let input: Input
    public let tools: [Tool]
    public let instructions: String?
    public let preset: String?
    public let maxOutputTokens: Int?
    public let maxSteps: Int?
    public let maxToolCalls: Int?
    public let reasoning: Reasoning?
    public var stream: Bool?
    public let store: Bool?
    public let background: Bool?
    public let temperature: Double?
    public let topP: Double?

    private enum CodingKeys: String, CodingKey {
        case model
        case input
        case tools
        case instructions
        case preset
        case maxOutputTokens = "max_output_tokens"
        case maxSteps        = "max_steps"
        case maxToolCalls    = "max_tool_calls"
        case reasoning
        case stream, store, background
        case temperature
        case topP            = "top_p"
    }

    public init(
        model: String,
        input: Input,
        tools: [Tool],
        instructions: String? = nil,
        preset: String? = nil,
        maxOutputTokens: Int? = nil,
        maxSteps: Int? = nil,
        maxToolCalls: Int? = nil,
        reasoning: Reasoning? = nil,
        stream: Bool? = nil,
        store: Bool? = nil,
        background: Bool? = nil,
        temperature: Double? = nil,
        topP: Double? = nil
    ) {
        self.model = model
        self.input = input
        self.tools = tools
        self.instructions = instructions
        self.preset = preset
        self.maxOutputTokens = maxOutputTokens
        self.maxSteps = maxSteps
        self.maxToolCalls = maxToolCalls
        self.reasoning = reasoning
        self.stream = stream
        self.store = store
        self.background = background
        self.temperature = temperature
        self.topP = topP
    }

    /// Convenience overload for the plain-text input case — preserves
    /// the original `init(model:input:tools:...)` ergonomics from
    /// before multimodal support landed.
    public init(
        model: String,
        input: String,
        tools: [Tool],
        instructions: String? = nil,
        preset: String? = nil,
        maxOutputTokens: Int? = nil,
        maxSteps: Int? = nil,
        maxToolCalls: Int? = nil,
        reasoning: Reasoning? = nil,
        stream: Bool? = nil,
        store: Bool? = nil,
        background: Bool? = nil,
        temperature: Double? = nil,
        topP: Double? = nil
    ) {
        self.init(
            model: model,
            input: .text(input),
            tools: tools,
            instructions: instructions,
            preset: preset,
            maxOutputTokens: maxOutputTokens,
            maxSteps: maxSteps,
            maxToolCalls: maxToolCalls,
            reasoning: reasoning,
            stream: stream,
            store: store,
            background: background,
            temperature: temperature,
            topP: topP
        )
    }

    /// Top-level `input` payload. Perplexity accepts either:
    ///   - a bare string (legacy, single-turn text-only), or
    ///   - an array of role-tagged messages with typed content blocks
    ///     (text + image, multi-turn).
    public enum Input: Encodable, Sendable {
        case text(String)
        case messages([InputMessage])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .messages(let messages):
                try container.encode(messages)
            }
        }
    }

    /// One turn in a multimodal `Input.messages` array.
    public struct InputMessage: Encodable, Sendable {
        public let role: Role
        public let content: [ContentBlock]

        public init(role: Role, content: [ContentBlock]) {
            self.role = role
            self.content = content
        }

        public enum Role: String, Encodable, Sendable {
            case user
            case assistant
            case system
            case developer
        }
    }

    /// Typed content block inside an `InputMessage.content` array.
    /// Perplexity Agent expects `input_text` / `input_image` (their
    /// own naming — note the `input_` prefix, distinct from OpenAI's
    /// Responses API which uses bare `text` / `image_url`).
    public enum ContentBlock: Encodable, Sendable {
        case inputText(String)
        /// `imageURL` accepts either a remote `https://...` URL or a
        /// `data:image/<mime>;base64,<...>` data URI.
        case inputImage(String)

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .inputText(let text):
                try container.encode("input_text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .inputImage(let url):
                try container.encode("input_image", forKey: .type)
                try container.encode(url, forKey: .imageURL)
            }
        }
    }

    /// Reasoning-effort knob for models that support chain-of-thought
    /// (e.g. `openai/gpt-5-mini`). Higher effort = more thinking
    /// tokens before the final answer.
    public struct Reasoning: Encodable, Sendable {
        public let effort: Effort

        public init(effort: Effort) {
            self.effort = effort
        }

        public enum Effort: String, Encodable, Sendable {
            case minimal
            case low
            case medium
            case high
        }
    }

    /// Tool definition. Per-tool budget knobs (max_tokens,
    /// max_tokens_per_page, max_results_per_query,
    /// max_results_per_request) are accepted for `people_search`,
    /// `web_search`, and `finance_search`; `fetch_url` ignores them.
    /// Pass `nil` to let Perplexity's defaults apply.
    public struct Tool: Encodable, Sendable {
        public let type: ToolType
        public let maxTokens: Int?
        public let maxTokensPerPage: Int?
        public let maxResultsPerQuery: Int?
        public let maxResultsPerRequest: Int?
        public let filters: Filters?
        public let userLocation: UserLocation?

        private enum CodingKeys: String, CodingKey {
            case type
            case maxTokens            = "max_tokens"
            case maxTokensPerPage     = "max_tokens_per_page"
            case maxResultsPerQuery   = "max_results_per_query"
            case maxResultsPerRequest = "max_results_per_request"
            case filters
            case userLocation = "user_location"
        }

        public init(
            type: ToolType,
            maxTokens: Int? = nil,
            maxTokensPerPage: Int? = nil,
            maxResultsPerQuery: Int? = nil,
            maxResultsPerRequest: Int? = nil,
            filters: Filters? = nil,
            userLocation: UserLocation? = nil
        ) {
            self.type = type
            self.maxTokens = maxTokens
            self.maxTokensPerPage = maxTokensPerPage
            self.maxResultsPerQuery = maxResultsPerQuery
            self.maxResultsPerRequest = maxResultsPerRequest
            self.filters = filters
            self.userLocation = userLocation
        }

        public struct Filters: Encodable, Sendable {
            public let searchRecencyFilter: String?

            private enum CodingKeys: String, CodingKey {
                case searchRecencyFilter = "search_recency_filter"
            }

            public init(searchRecencyFilter: String? = nil) {
                self.searchRecencyFilter = searchRecencyFilter
            }
        }

        public struct UserLocation: Encodable, Sendable {
            public let country: String

            public init(country: String) { self.country = country }
        }

        public static let webSearch     = Tool(type: .webSearch)
        public static let peopleSearch  = Tool(type: .peopleSearch)
        public static let financeSearch = Tool(type: .financeSearch)
        public static let fetchURL      = Tool(type: .fetchURL)
    }

    public enum ToolType: String, Encodable, Sendable {
        case webSearch     = "web_search"
        case peopleSearch  = "people_search"
        case financeSearch = "finance_search"
        case fetchURL      = "fetch_url"
    }
}
