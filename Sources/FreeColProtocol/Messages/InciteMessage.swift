import Foundation

public struct InciteMessage: FreeColMessage {
    public static let tag = "incite"

    public let settlement: String?
    public let gold: String?
    public let enemy: String?
    public let unit: String?

    public init(
        settlement: String? = nil,
        gold: String? = nil,
        enemy: String? = nil,
        unit: String? = nil
    ) {
        self.settlement = settlement
        self.gold = gold
        self.enemy = enemy
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.settlement = attributes["settlement"]
        self.gold = attributes["gold"]
        self.enemy = attributes["enemy"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = settlement { attrs["settlement"] = v }
        if let v = gold { attrs["gold"] = v }
        if let v = enemy { attrs["enemy"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
