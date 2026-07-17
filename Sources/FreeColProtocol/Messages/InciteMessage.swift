import Foundation

public struct InciteMessage: FreeColMessage {
    public static let tag = "incite"

    public let gold: String?
    public let settlement: String?
    public let enemy: String?
    public let unit: String?

    public init(
        gold: String? = nil,
        settlement: String? = nil,
        enemy: String? = nil,
        unit: String? = nil
    ) {
        self.gold = gold
        self.settlement = settlement
        self.enemy = enemy
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.gold = attributes["gold"]
        self.settlement = attributes["settlement"]
        self.enemy = attributes["enemy"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = gold { attrs["gold"] = v }
        if let v = settlement { attrs["settlement"] = v }
        if let v = enemy { attrs["enemy"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
