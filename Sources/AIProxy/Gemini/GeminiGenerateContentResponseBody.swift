//
//  GeminiChatCompletionResponseBody.swift
//
//
//  Created by Todd Hamilton on 10/14/24.
//

import Foundation

/// Format taken from here:
/// https://ai.google.dev/api/generate-content#generatecontentresponse
nonisolated public struct GeminiGenerateContentResponseBody: Decodable, Sendable {
    /// Candidate responses from the mode
    public let candidates: [Candidate]?

    /// Metadata on the generation requests' token usage.
    public let usageMetadata: UsageMetadata?
    
    public init(candidates: [Candidate]?, usageMetadata: UsageMetadata?) {
        self.candidates = candidates
        self.usageMetadata = usageMetadata
    }
}

// MARK: - ResponseBody.Candidate
extension GeminiGenerateContentResponseBody {
    /// A response candidate generated from the model.
    /// See: https://ai.google.dev/api/generate-content#candidate
    nonisolated public struct Candidate: Decodable, Sendable {
        /// Generated content returned from the model.
        public let content: Content?

        /// The reason why the model stopped generating tokens.
        /// If empty, the model has not stopped generating tokens.
        public let finishReason: String?

        ///  Grounding metadata for the candidate.
        public let groundingMetadata: GroundingMetadata?

        /// Index of the candidate in the list of response candidates.
        public let index: Int?

        /// List of ratings for the safety of a response candidate.
        /// There is at most one rating per category.
        public let safetyRatings: [SafetyRating]?
        
        public init(content: Content?, finishReason: String?, groundingMetadata: GroundingMetadata?, index: Int?, safetyRatings: [SafetyRating]?) {
            self.content = content
            self.finishReason = finishReason
            self.groundingMetadata = groundingMetadata
            self.index = index
            self.safetyRatings = safetyRatings
        }
    }
}

// MARK: - ResponseBody.Candidate.Content
extension GeminiGenerateContentResponseBody.Candidate {
    /// The base structured datatype containing multi-part content of a message.
    /// See https://ai.google.dev/api/caching#Content
    ///
    /// A Content includes a role field designating the producer of the Content and a parts
    /// field containing multi-part data that contains the content of the message turn.
    nonisolated public struct Content: Decodable, Sendable {
        /// Ordered Parts that constitute a single message. Parts may have different MIME types.
        /// Part kinds this SDK does not model are left out (see `init(from:)`).
        public let parts: [Part]?

        /// The producer of the content. Either 'user' or 'model'.
        public let role: String?
        
        public init(parts: [Part]?, role: String?) {
            self.parts = parts
            self.role = role
        }

        private enum CodingKeys: String, CodingKey {
            case parts
            case role
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.role = try container.decodeIfPresent(String.self, forKey: .role)
            // `Part` is an open union: executableCode, codeExecutionResult, functionResponse,
            // fileData, videoMetadata and future kinds have no case here. Skip such a part
            // instead of failing the whole response — a streaming caller that treats an
            // undecodable chunk as fatal would otherwise lose the entire answer.
            self.parts = try container
                .decodeIfPresent([LossyPart].self, forKey: .parts)?
                .compactMap(\.part)
        }

        private struct LossyPart: Decodable {
            let part: Part?

            init(from decoder: any Decoder) throws {
                self.part = try? Part(from: decoder)
            }
        }
    }
}

// MARK: - ResponseBody.Candidate.Content.Part
extension GeminiGenerateContentResponseBody.Candidate.Content {
    /// A datatype containing media that is part of a multi-part Content message.
    /// This field is a union type, but currently only `text` is supported.
    /// See: https://ai.google.dev/api/caching#Part
    nonisolated public enum Part: Decodable, Sendable {
        case text(String, thoughtSignature: String? = nil)
        /// A thought summary (`"thought": true`), returned while the model
        /// reasons when the request sets `thinkingConfig.includeThoughts`.
        /// It is not part of the answer.
        case thought(String, thoughtSignature: String? = nil)
        case functionCall(name: String, args: [String: any Sendable]?, thoughtSignature: String? = nil)
        case inlineData(mimeType: String, base64Data: String, thoughtSignature: String? = nil)
        /// An interim image the model drew while reasoning (`"thought": true` on an inline-data
        /// part, returned by Gemini 3 image models). It is not the result.
        case thoughtImage(mimeType: String, base64Data: String, thoughtSignature: String? = nil)

        private enum CodingKeys: String, CodingKey {
            case text
            case thought
            case functionCall
            case inlineData
            case thoughtSignature
        }

        private struct _FunctionCall: Decodable, Sendable {
            let name: String
            let args: [String: AIProxyJSONValue]?

            public init(name: String, args: [String : AIProxyJSONValue]?) {
                self.name = name
                self.args = args
            }
        }

        private struct _InlineData: Decodable, Sendable {
            let mimeType: String
            let data: String

            public init(mimeType: String, data: String) {
                self.mimeType = mimeType
                self.data = data
            }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let thoughtSignature = try container.decodeIfPresent(String.self, forKey: .thoughtSignature)
            let isThought = try container.decodeIfPresent(Bool.self, forKey: .thought) == true
            if let functionCall = try container.decodeIfPresent(_FunctionCall.self, forKey: .functionCall) {
                self = .functionCall(name: functionCall.name, args: functionCall.args?.untypedDictionary, thoughtSignature: thoughtSignature)
            } else if let inlineData = try container.decodeIfPresent(_InlineData.self, forKey: .inlineData) {
                self = isThought
                    ? .thoughtImage(mimeType: inlineData.mimeType, base64Data: inlineData.data, thoughtSignature: thoughtSignature)
                    : .inlineData(mimeType: inlineData.mimeType, base64Data: inlineData.data, thoughtSignature: thoughtSignature)
            } else if isThought {
                // A thought may carry only its signature.
                self = .thought(try container.decodeIfPresent(String.self, forKey: .text) ?? "", thoughtSignature: thoughtSignature)
            } else if let text = try container.decodeIfPresent(String.self, forKey: .text) {
                self = .text(text, thoughtSignature: thoughtSignature)
            } else if let thoughtSignature {
                // A signature-only part: keep the signature, it may have to go back.
                self = .text("", thoughtSignature: thoughtSignature)
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported Gemini part kind"
                ))
            }
        }

    }
}


// MARK: - ResponseBody.Candidate.SafetyRating
extension GeminiGenerateContentResponseBody.Candidate {
    /// Ratings for safety of the prompt. There is at most one rating per category.
    /// See https://ai.google.dev/api/generate-content#v1beta.SafetyRating
    nonisolated public struct SafetyRating: Decodable, Sendable {
        /// Was this content blocked because of this rating?
        public let blocked: Bool?

        /// The category for this rating.
        public let category: String?

        /// The probability of harm for this content.
        public let probability: String?
        
        public init(blocked: Bool?, category: String?, probability: String?) {
            self.blocked = blocked
            self.category = category
            self.probability = probability
        }
    }
}

// Extension to handle grounding metadata in the response
extension GeminiGenerateContentResponseBody.Candidate {
    /// Grounding metadata containing information about search results used for the response
    nonisolated public struct GroundingMetadata: Decodable, Sendable {
        public let searchEntryPoint: SearchEntryPoint?
        public let groundingChunks: [GroundingChunk]?
        public let groundingSupports: [GroundingSupport]?
        public let webSearchQueries: [String]?
        
        public init(searchEntryPoint: SearchEntryPoint?, groundingChunks: [GroundingChunk]?, groundingSupports: [GroundingSupport]?, webSearchQueries: [String]?) {
            self.searchEntryPoint = searchEntryPoint
            self.groundingChunks = groundingChunks
            self.groundingSupports = groundingSupports
            self.webSearchQueries = webSearchQueries
        }
        
        private enum CodingKeys: String, CodingKey {
            case searchEntryPoint
            case groundingChunks
            case groundingSupports
            case webSearchQueries
        }
    }
    
    nonisolated public struct SearchEntryPoint: Decodable, Sendable {
        public let renderedContent: String?
        
        public init(renderedContent: String?) {
            self.renderedContent = renderedContent
        }
    }
    
    nonisolated public struct GroundingChunk: Decodable, Sendable {
        public let web: WebInfo?
        
        public init(web: WebInfo?) {
            self.web = web
        }
    }
    
    nonisolated public struct WebInfo: Decodable, Sendable {
        public let uri: String?
        public let title: String?
        public var url: URL? {
            guard let uri = self.uri else {
                return nil
            }
            return URL(string: uri)
        }

        public init(uri: String?, title: String?) {
            self.uri = uri
            self.title = title
        }
    }
    
    nonisolated public struct GroundingSupport: Decodable, Sendable {
        public let segment: Segment?
        public let groundingChunkIndices: [Int]?
        public let confidenceScores: [Double]?
        
        public init(segment: Segment?, groundingChunkIndices: [Int]?, confidenceScores: [Double]?) {
            self.segment = segment
            self.groundingChunkIndices = groundingChunkIndices
            self.confidenceScores = confidenceScores
        }
    }
    
    nonisolated public struct Segment: Decodable, Sendable {
        public let startIndex: Int?
        public let endIndex: Int?
        public let text: String?
        
        public init(startIndex: Int?, endIndex: Int?, text: String?) {
            self.startIndex = startIndex
            self.endIndex = endIndex
            self.text = text
        }
    }
}

// MARK: - ResponseBody.UsageMetadata
extension GeminiGenerateContentResponseBody {
    /// Metadata on the generation request's token usage.
    nonisolated public struct UsageMetadata: Decodable, Sendable {
        /// Number of tokens in the cached part of the prompt (the cached content)
        public let cachedContentTokenCount: Int?

        /// Total number of tokens across all the generated response candidates.
        public let candidatesTokenCount: Int?

        /// Number of tokens in the prompt. When cachedContent is set, this is still the total
        /// effective prompt size meaning this includes the number of tokens in the cached
        /// content.
        public let promptTokenCount: Int?

        /// Total token count for the generation request (prompt + response candidates).
        public let totalTokenCount: Int?

        /// The number of tokens allocated for thinking.
        public let thoughtsTokenCount: Int?
        
        public init(cachedContentTokenCount: Int?, candidatesTokenCount: Int?, promptTokenCount: Int?, totalTokenCount: Int?, thoughtsTokenCount: Int?) {
            self.cachedContentTokenCount = cachedContentTokenCount
            self.candidatesTokenCount = candidatesTokenCount
            self.promptTokenCount = promptTokenCount
            self.totalTokenCount = totalTokenCount
            self.thoughtsTokenCount = thoughtsTokenCount
        }
    }
}
