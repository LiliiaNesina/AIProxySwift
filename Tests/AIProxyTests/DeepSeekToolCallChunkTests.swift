import Foundation
import XCTest
@testable import AIProxy

final class DeepSeekToolCallChunkTests: XCTestCase {
    func testStreamedToolCallDeltasAreDecoded() throws {
        let json = #"{"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{\"query\":"}}]}}]}"#
        let chunk = try JSONDecoder().decode(DeepSeekChatCompletionChunk.self, from: Data(json.utf8))
        XCTAssertEqual(chunk.choices.first?.delta.toolCalls?.first?.index, 0)
        XCTAssertEqual(chunk.choices.first?.delta.toolCalls?.first?.function?.name, "web_search")
    }
}
