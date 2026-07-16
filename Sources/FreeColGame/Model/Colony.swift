import Foundation
import FreeColProtocol

public struct Colony: GameObject, PartiallyUpdatable, Identifiable {
    public var id: String
    public var name: String?
    public var owner: String?
    public var tileId: String?
    public var settlementType: String?
    public var established: Int = 0
    public var sonsOfLiberty: Int = 0
    public var liberty: Int = 0
    public var immigration: Int = 0
    public var productionBonus: Int = 0
    public var unitCount: Int = 0

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
    }

    public mutating func applyPartial(attributes: Attributes) {
        if let v = attributes["name"] { name = v }
        if let v = attributes["owner"] { owner = v }
        if let v = attributes["tile"] { tileId = v }
        if let v = attributes["settlementType"] { settlementType = v }
        established = attributes.int("established", default: established)
        sonsOfLiberty = attributes.int("sonsOfLiberty", default: sonsOfLiberty)
        liberty = attributes.int("liberty", default: liberty)
        immigration = attributes.int("immigration", default: immigration)
        productionBonus = attributes.int("productionBonus", default: productionBonus)
        unitCount = attributes.int("unitCount", default: unitCount)
    }
}
