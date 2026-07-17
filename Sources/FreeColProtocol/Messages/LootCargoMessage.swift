import Foundation

public struct LootCargoMessage: FreeColMessage {
    public static let tag = "lootCargo"

    public let loser: String?
    public let winner: String?
    public let children: [ParsedMessage]

    public init(
        loser: String? = nil,
        winner: String? = nil
    ) {
        self.loser = loser
        self.winner = winner
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.loser = attributes["loser"]
        self.winner = attributes["winner"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = loser { attrs["loser"] = v }
        if let v = winner { attrs["winner"] = v }
        return (attrs, [])
    }
}
