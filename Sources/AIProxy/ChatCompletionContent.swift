import Foundation

/// Mistral Large 4 returns text/thinking chunks where compatible APIs
/// traditionally return a string. Keep reasoning separate from the answer.
nonisolated struct ChatCompletionContent: Decodable, Sendable {
    let text: String?
    let reasoning: String?

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            text = nil
            reasoning = nil
        } else if let string = try? value.decode(String.self) {
            text = string
            reasoning = nil
        } else {
            let chunks = try value.decode([Chunk].self)
            let texts = chunks.filter { $0.type == "text" }.compactMap(\.text)
            let thoughts = chunks.filter { $0.type == "thinking" }.flatMap { $0.thinking ?? [] }.map(\.text)
            text = texts.isEmpty ? nil : texts.joined()
            reasoning = thoughts.isEmpty ? nil : thoughts.joined()
        }
    }

    func reasoning(appendingTo explicit: String?) -> String? {
        guard explicit != nil || reasoning != nil else { return nil }
        return (explicit ?? "") + (reasoning ?? "")
    }

    private struct Chunk: Decodable, Sendable {
        let type: String
        let text: String?
        let thinking: [Thought]?

        private enum CodingKeys: String, CodingKey { case type, text, thinking }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            switch type {
            case "text":
                text = try c.decode(String.self, forKey: .text)
                thinking = nil
            case "thinking":
                text = nil
                thinking = try c.decode([Thought].self, forKey: .thinking)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unsupported chat content chunk")
            }
        }
    }

    private struct Thought: Decodable, Sendable {
        let type: String
        let text: String

        private enum CodingKeys: String, CodingKey { case type, text }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            guard type == "text" else {
                throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unsupported thinking chunk")
            }
            text = try c.decode(String.self, forKey: .text)
        }
    }
}
