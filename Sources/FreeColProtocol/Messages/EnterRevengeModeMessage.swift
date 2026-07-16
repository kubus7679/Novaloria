import Foundation

public struct EnterRevengeModeMessage: FreeColMessage {
    public static let tag = "enterRevengeMode"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}
