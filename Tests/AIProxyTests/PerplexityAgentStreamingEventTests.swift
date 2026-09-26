import Foundation
import XCTest
@testable import AIProxy

final class PerplexityAgentStreamingEventTests: XCTestCase {
    func testCompletedResponseKeepsStringSourceIDs() throws {
        let json = #"{"type":"response.completed","response":{"status":"completed","output":[{"type":"search_results","results":[{"id":"7","url":"https://example.com/a","title":"A"}]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Result [7]"}]}],"usage":{"cost":{"currency":"USD","total_cost":0.003}}}}"#
        let event = try JSONDecoder().decode(PerplexityAgentStreamingEvent.self, from: Data(json.utf8))
        guard case .completed(let response) = event else { return XCTFail("Expected completion") }
        XCTAssertEqual(response.assistantText, "Result [7]")
        XCTAssertEqual(response.allSearchResults.first?.id, 7)
        XCTAssertEqual(response.usage?.cost?.totalCost, 0.003)
    }

    func testNativeSearchRequestEncodesTypedFiltersAndPrivateStream() throws {
        let body = PerplexityAgentRequestBody(
            model: "perplexity-fast", input: "Today", tools: [
                .init(type: .webSearch,
                      filters: .init(searchRecencyFilter: "day"),
                      userLocation: .init(country: "UA"))
            ], stream: true, store: false, background: false
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["store"] as? Bool, false)
        XCTAssertEqual(json["background"] as? Bool, false)
        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertEqual((tools[0]["filters"] as? [String: String])?["search_recency_filter"], "day")
    }
}
