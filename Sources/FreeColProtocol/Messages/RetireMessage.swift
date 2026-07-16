import Foundation

public struct RetireMessage: FreeColMessage {
    public static let tag = "retire"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}
