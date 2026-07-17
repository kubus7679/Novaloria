import Foundation

public struct InciteMessage: FreeColMessage {
    public static let tag = "incite"

    public let unit: String?
    public let settlement: String?
    public let enemy: String?
    public let gold: String?

    public init(
        unit: String? = nil,
        settlement: String? = nil,
        enemy: String? = nil,
        gold: String? = nil
    ) {
        self.unit = unit
        self.settlement = settlement
        self.enemy = enemy
        self.gold = gold
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.settlement = attributes["settlement"]
        self.enemy = attributes["enemy"]
        self.gold = attributes["gold"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = settlement { attrs["settlement"] = v }
        if let v = enemy { attrs["enemy"] = v }
        if let v = gold { attrs["gold"] = v }
        return (attrs, [])
    }
}
