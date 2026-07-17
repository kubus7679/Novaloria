import Foundation

public struct LootCargoMessage: FreeColMessage {
    public static let tag = "lootCargo"

    public let winner: String?
    public let loser: String?
    public let children: [ParsedMessage]

    public init(
        winner: String? = nil,
        loser: String? = nil
    ) {
        self.winner = winner
        self.loser = loser
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.winner = attributes["winner"]
        self.loser = attributes["loser"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = winner { attrs["winner"] = v }
        if let v = loser { attrs["loser"] = v }
        return (attrs, [])
    }
}
