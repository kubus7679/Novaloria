import Foundation
import FreeColProtocol

/// A building present in a colony, as serialized in `<building>` children.
public struct ColonyBuilding: Sendable, Identifiable {
    public var id: String
    public var buildingType: String?

    public init(id: String, buildingType: String?) {
        self.id = id
        self.buildingType = buildingType
    }
}

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
    /// Ordered build queue (`<buildQueueItem id=..>`).
    public var buildQueue: [String] = []
    /// Ordered population (immigration) queue (`<populationQueueItem id=..>`).
    public var populationQueue: [String] = []
    /// Buildings present in the colony.
    public var buildings: [ColonyBuilding] = []
    /// Stored goods, keyed by goods type id (from `<goodsContainer>`).
    public var goods: [String: Int] = [:]

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
        for child in children {
            switch child.tag {
            case "buildQueueItem":
                if let itemId = child.attributes["id"] { buildQueue.append(itemId) }
            case "populationQueueItem":
                if let itemId = child.attributes["id"] { populationQueue.append(itemId) }
            case "building":
                buildings.append(ColonyBuilding(id: child.attributes["id"] ?? "",
                                                buildingType: child.attributes["buildingType"]))
            case "goodsContainer":
                for storage in child.children where storage.tag == "storedGoods" {
                    for goodsNode in storage.children where goodsNode.tag == "goods" {
                        if let type = goodsNode.attributes["type"] {
                            goods[type] = goodsNode.attributes.int("amount")
                        }
                    }
                }
            default:
                break
            }
        }
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
