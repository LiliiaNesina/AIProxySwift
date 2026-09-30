import Foundation

nonisolated public struct AIProxyModelControls: Encodable, Sendable {
    public let version = 1
    public let values: [String: AIProxyJSONValue]

    public init(values: [String: AIProxyJSONValue]) {
        self.values = values
    }
}
