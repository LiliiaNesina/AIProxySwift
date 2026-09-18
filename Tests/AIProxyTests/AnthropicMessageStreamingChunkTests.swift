//
//  AnthropicMessageStreamingChunkTests.swift
//
//
//  Created by Lou Zell on 10/7/24.
//

import XCTest
import Foundation
@testable import AIProxy


final class AnthropicMessageStreamingChunkTests: XCTestCase {

    func testContentBlockDeltaIsDecodable() {
        let serializedChunk = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello! How"}}"#
        let contentBlockDelta = AnthropicContentBlockDelta.deserialize(fromLine: serializedChunk)
        switch contentBlockDelta?.delta {
        case .textDelta(let textDelta):
            XCTAssertEqual("Hello! How", textDelta.text)
        default:
            XCTFail()
        }
    }

    func testContentBlockStartIsDecodable() {
        let serializedChunk = #"data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01T1x1fJ34qAmk2tNTrN7Up6","name":"get_weather","input":{}}}"#
        let contentBlockStart = AnthropicContentBlockStart.deserialize(fromLine: serializedChunk)
        switch contentBlockStart?.contentBlock {
        case .toolUseBlock(let toolUseBlock):
            XCTAssertEqual("get_weather", toolUseBlock.name)
            XCTAssertEqual("toolu_01T1x1fJ34qAmk2tNTrN7Up6", toolUseBlock.id)
        default:
            XCTFail()
        }
    }

    /// The event may carry `output_tokens` alone. It must still decode, stop reason included.
    func testMessageDeltaWithOutputTokensOnlyIsDecodable() throws {
        let json = #"{"type": "message_delta", "delta": {"stop_reason": "max_tokens", "stop_sequence":null}, "usage": {"output_tokens": 15}}"#
        let event = try JSONDecoder().decode(AnthropicStreamingEvent.self, from: Data(json.utf8))
        guard case .messageDelta(let messageDelta) = event else { return XCTFail() }
        XCTAssertEqual(.maxTokens, messageDelta.delta.stopReason)
        XCTAssertEqual(15, messageDelta.usage?.outputTokens)
        XCTAssertNil(messageDelta.usage?.inputTokens)
    }

    func testMessageDeltaWithFullUsageIsDecodable() throws {
        let json = #"{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"input_tokens":10682,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":510,"server_tool_use":{"web_search_requests":1}}}"#
        let event = try JSONDecoder().decode(AnthropicStreamingEvent.self, from: Data(json.utf8))
        guard case .messageDelta(let messageDelta) = event else { return XCTFail() }
        XCTAssertEqual(.endTurn, messageDelta.delta.stopReason)
        XCTAssertEqual(10682, messageDelta.usage?.inputTokens)
        XCTAssertEqual(510, messageDelta.usage?.outputTokens)
    }

    /// A server tool this SDK does not count yet must not cost the token counts.
    func testMessageDeltaKeepsTokenCountsWithUnfamiliarServerToolUsage() throws {
        let json = #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":15,"server_tool_use":{"web_fetch_requests":1}}}"#
        let event = try JSONDecoder().decode(AnthropicStreamingEvent.self, from: Data(json.utf8))
        guard case .messageDelta(let messageDelta) = event else { return XCTFail() }
        XCTAssertEqual(15, messageDelta.usage?.outputTokens)
        XCTAssertNil(messageDelta.usage?.serverToolUse)
    }

    /// Null counts, a missing usage object and an unexpected usage shape all keep the stop reason.
    func testMessageDeltaSurvivesMissingOrUnexpectedUsage() throws {
        let lines = [
            #"{"type":"message_delta","delta":{"stop_reason":"refusal","stop_sequence":null},"usage":{"input_tokens":null,"output_tokens":510}}"#,
            #"{"type": "message_delta", "delta": {"stop_reason": "refusal", "stop_sequence": null}}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"refusal"},"usage":"unexpected"}"#,
        ]
        for json in lines {
            let event = try JSONDecoder().decode(AnthropicStreamingEvent.self, from: Data(json.utf8))
            guard case .messageDelta(let messageDelta) = event else { return XCTFail(json) }
            XCTAssertEqual(.refusal, messageDelta.delta.stopReason, json)
        }
    }
}
