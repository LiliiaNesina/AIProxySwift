import Foundation

/// Typed events from `POST /v1/agent` with `stream: true`.
/// The terminal response is authoritative for text, sources and usage.
nonisolated public enum PerplexityAgentStreamingEvent: Decodable, Sendable {
    case outputTextDelta(String)
    case outputItemDone(PerplexityAgentResponseBody.OutputItem)
    case completed(PerplexityAgentResponseBody)
    case failed
    case other

    private enum CodingKeys: String, CodingKey {
        case type, delta, item, response
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(String.self, forKey: .type) {
        case "response.output_text.delta":
            self = .outputTextDelta(try values.decode(String.self, forKey: .delta))
        case "response.output_item.done":
            self = .outputItemDone(try values.decode(PerplexityAgentResponseBody.OutputItem.self, forKey: .item))
        case "response.completed":
            self = .completed(try values.decode(PerplexityAgentResponseBody.self, forKey: .response))
        case "response.failed", "response.incomplete", "error":
            self = .failed
        default:
            self = .other
        }
    }
}
