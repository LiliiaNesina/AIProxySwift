import XCTest
@testable import AIProxy

final class OctoberModelContractTests: XCTestCase {
    private let chunks = #"[{"type":"thinking","thinking":[{"type":"text","text":"calculate"}]},{"type":"text","text":"391"}]"#

    func testLarge4NativeAndProxyStreamsPreserveReasoningToolsAndUsage() throws {
        for content in [chunks, #""391""#] {
            let json = #"{"choices":[{"delta":{"content":\#(content),"reasoning_content":"prefix:","tool_calls":[{"index":0,"id":"tool1","type":"function","function":{"name":"lookup","arguments":"{}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":15,"completion_tokens":151,"total_tokens":166}}"#
            let data = Data(json.utf8)
            let openAI = try JSONDecoder().decode(OpenAIChatCompletionChunk.self, from: data)
            XCTAssertEqual(openAI.choices[0].delta.content, "391")
            XCTAssertEqual(openAI.choices[0].delta.reasoningContent, content == chunks ? "prefix:calculate" : "prefix:")
            XCTAssertEqual(openAI.choices[0].delta.toolCalls?.first?.function?.name, "lookup")
            XCTAssertEqual(openAI.choices[0].finishReason, "tool_calls")
            XCTAssertEqual(openAI.usage?.completionTokens, 151)
            let mistral = try JSONDecoder().decode(MistralChatCompletionStreamingChunk.self, from: data)
            XCTAssertEqual(mistral.choices[0].delta.content, "391")
            XCTAssertEqual(mistral.choices[0].delta.reasoningContent, openAI.choices[0].delta.reasoningContent)
            XCTAssertEqual(mistral.usage?.completionTokens, 151)
        }
    }

    func testLarge4NonStreamChunksAndExistingStringMessages() throws {
        for content in [chunks, #""391""#] {
            let json = #"{"created":1,"model":"mistral-large-4","choices":[{"message":{"role":"assistant","content":\#(content)},"finish_reason":"stop"}]}"#
            let data = Data(json.utf8)
            let openAI = try JSONDecoder().decode(OpenAIChatCompletionResponseBody.self, from: data)
            let mistral = try JSONDecoder().decode(MistralChatCompletionResponseBody.self, from: data)
            XCTAssertEqual(openAI.choices[0].message.content, "391")
            XCTAssertEqual(mistral.choices[0].message.content, "391")
            XCTAssertEqual(openAI.choices[0].message.reasoningContent, content == chunks ? "calculate" : nil)
            XCTAssertEqual(mistral.choices[0].message.reasoningContent, openAI.choices[0].message.reasoningContent)
        }
    }

    func testThinkingOnlyAndNullContentNeverBecomeAnswerText() throws {
        let json = #"{"choices":[{"delta":{"content":[{"type":"thinking","thinking":[{"type":"text","text":"private"}]}]}},{"delta":{"content":null,"reasoning_content":"summary"}}]}"#
        let response = try JSONDecoder().decode(OpenAIChatCompletionChunk.self, from: Data(json.utf8))
        XCTAssertNil(response.choices[0].delta.content)
        XCTAssertEqual(response.choices[0].delta.reasoningContent, "private")
        XCTAssertNil(response.choices[1].delta.content)
        XCTAssertEqual(response.choices[1].delta.reasoningContent, "summary")
    }

    func testUnsupportedChunksFailInsteadOfSilentlyLosingAnswer() {
        let json = #"{"choices":[{"delta":{"content":[{"type":"unknown","text":"answer"}]}}]}"#
        XCTAssertThrowsError(try JSONDecoder().decode(OpenAIChatCompletionChunk.self, from: Data(json.utf8)))
    }

    func testNanoBanana21UsageKeepsModalitiesAndSeparateThinking() throws {
        let json = #"{"usageMetadata":{"promptTokenCount":1156,"candidatesTokenCount":1488,"thoughtsTokenCount":483,"totalTokenCount":3127,"promptTokensDetails":[{"modality":"IMAGE","tokenCount":1120},{"modality":"TEXT","tokenCount":36}],"candidatesTokensDetails":[{"modality":"IMAGE","tokenCount":1120}]}}"#
        let response = try JSONDecoder().decode(GeminiGenerateContentResponseBody.self, from: Data(json.utf8))
        XCTAssertEqual(response.usageMetadata?.promptTokensDetails?.first?.tokenCount, 1120)
        XCTAssertEqual(response.usageMetadata?.candidatesTokensDetails?.first?.modality, "IMAGE")
        XCTAssertEqual(response.usageMetadata?.thoughtsTokenCount, 483)
        XCTAssertEqual(response.usageMetadata?.candidatesTokenCount, 1488)
    }

    func testHaiku55RequestUsesAdaptiveOrDisabledWithoutBudget() throws {
        for thinking in [AnthropicThinkingConfigParam.adaptive, .disabled] {
            let request = AnthropicMessageRequestBody(maxTokens: 16384,
                messages: [AnthropicMessageParam(content: [.textBlock(AnthropicTextBlockParam(text: "Hello"))], role: .user)],
                model: "claude-haiku-5-5", thinking: thinking, outputConfig: AnthropicOutputConfig(effort: "medium"))
            let json = try JSONSerialization.jsonObject(with: Data(request.serialize().utf8)) as! [String: Any]
            XCTAssertEqual(json["model"] as? String, "claude-haiku-5-5")
            let control = json["thinking"] as! [String: Any]
            XCTAssertTrue(["adaptive", "disabled"].contains(control["type"] as! String))
            XCTAssertNil(control["budget_tokens"])
        }
    }

    func testHaiku55EmptyThinkingStillKeepsSignature() throws {
        let json = #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":"signed-thinking"}}"#
        let event = try JSONDecoder().decode(AnthropicStreamingEvent.self, from: Data(json.utf8))
        guard case .contentBlockStart(let start) = event,
              case .thinkingBlock(let block) = start.contentBlock else { return XCTFail("Missing thinking block") }
        XCTAssertEqual(block.thinking, "")
        XCTAssertEqual(block.signature, "signed-thinking")
    }
}
