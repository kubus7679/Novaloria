import Foundation

public struct ReconnectMessage: FreeColMessage {
    public static let tag = "reconnect"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}
