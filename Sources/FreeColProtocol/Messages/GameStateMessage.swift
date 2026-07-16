import Foundation

public struct GameStateMessage: FreeColMessage {
    public static let tag = "gameState"

    public let state: String?

    public init(
        state: String? = nil
    ) {
        self.state = state
    }

    public init(attributes: Attributes, children: Children) throws {
        self.state = attributes["state"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = state { attrs["state"] = v }
        return (attrs, [])
    }
}
