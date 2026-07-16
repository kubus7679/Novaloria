import Foundation

public struct StartGameMessage: FreeColMessage {
    public static let tag = "startGame"

    public init() {}

    public init(attributes: Attributes, children: Children) throws {
        // No attributes or children expected
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        return ([:], [])
    }
}
