import Foundation

public struct DisconnectMessage: FreeColMessage {
    public static let tag = "disconnect"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}
