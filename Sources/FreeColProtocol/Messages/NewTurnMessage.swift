import Foundation

public struct NewTurnMessage: FreeColMessage {
    public static let tag = "newTurn"

    public let turn: String?

    public init(
        turn: String? = nil
    ) {
        self.turn = turn
    }

    public init(attributes: Attributes, children: Children) throws {
        self.turn = attributes["turn"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = turn { attrs["turn"] = v }
        return (attrs, [])
    }
}
