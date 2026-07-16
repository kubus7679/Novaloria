import Foundation

public struct SetCurrentPlayerMessage: FreeColMessage {
    public static let tag = "setCurrentPlayer"

    public let player: String?

    public init(
        player: String? = nil
    ) {
        self.player = player
    }

    public init(attributes: Attributes, children: Children) throws {
        self.player = attributes["player"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = player { attrs["player"] = v }
        return (attrs, [])
    }
}
