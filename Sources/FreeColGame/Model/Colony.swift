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

/// Custom-house export/import settings for one goods type (`<exportData>`).
public struct ColonyExportData: Sendable, Identifiable {
    public var id: String { goodsType }
    public var goodsType: String
    public var exported: Bool
    public var importLevel: Int
    public var exportLevel: Int
    public var highLevel: Int
    public var lowLevel: Int

    public init(goodsType: String,
                exported: Bool,
                importLevel: Int,
                exportLevel: Int,
                highLevel: Int,
                lowLevel: Int) {
        self.goodsType = goodsType
        self.exported = exported
        self.importLevel = importLevel
        self.exportLevel = exportLevel
        self.highLevel = highLevel
        self.lowLevel = lowLevel
    }
}

/// A work location inside a colony (a colony tile or a building), used to
/// address worker assignments in `work`/`rearrangeColony`.
public struct ColonyWorkLocation: Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case colonyTile
        case building
    }

    public var id: String
    public var kind: Kind
    public var tileId: String?
    public var buildingType: String?
    /// Selected base outputs; nil means the server omitted the production type.
    public var productionOutputs: [String: Int]?

    public init(id: String, kind: Kind, tileId: String? = nil, buildingType: String? = nil,
                productionOutputs: [String: Int]? = nil) {
        self.id = id
        self.kind = kind
        self.tileId = tileId
        self.buildingType = buildingType
        self.productionOutputs = productionOutputs
    }

    public mutating func applyUpdate(attributes: Attributes, children: [ParsedMessage]) {
        if let tile = attributes["workTile"] ?? attributes["tile"] ?? attributes["work-tile"] {
            tileId = tile
        }
        if let production = children.first(where: { $0.tag == "production" }) {
            productionOutputs = [:]
            for output in production.children where output.tag == "output" {
                if let goods = output.attributes["goods-type"] {
                    productionOutputs?[goods] = output.attributes.int("value")
                }
            }
        }
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
    /// Custom-house export/import settings, keyed by goods type id.
    public var exportData: [String: ColonyExportData] = [:]
    /// Colony tile work locations (buildings are tracked in `buildings`).
    public var workTiles: [ColonyWorkLocation] = []
    // Native settlement details (present for `<indianSettlement>` objects).
    /// Skill a free colonist can learn here.
    public var learnableSkill: String?
    /// Goods the settlement wants to buy.
    public var wantedGoods: [String] = []
    /// The player this settlement hates most.
    public var mostHated: String?
    /// Alarm level per player id.
    public var alarm: [String: Int] = [:]

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
            case "exportData":
                if let goodsType = child.attributes["id"] {
                    exportData[goodsType] = ColonyExportData(
                        goodsType: goodsType,
                        exported: child.attributes.bool("exported", default: false),
                        importLevel: child.attributes.int("importLevel", default: -1),
                        exportLevel: child.attributes.int("exportLevel", default: 50),
                        highLevel: child.attributes.int("highLevel", default: 90),
                        lowLevel: child.attributes.int("lowLevel", default: 10)
                    )
                }
            case "colonyTile":
                let tileId = child.attributes["workTile"]
                    ?? child.attributes["tile"]
                    ?? child.attributes["work-tile"]
                var location = ColonyWorkLocation(
                    id: child.attributes["id"] ?? tileId ?? "",
                    kind: .colonyTile,
                    tileId: tileId
                )
                location.applyUpdate(attributes: child.attributes, children: child.children)
                workTiles.append(location)
            case "alarm":
                if let playerId = child.attributes["player"] {
                    alarm[playerId] = child.attributes.int("value")
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
        if let v = attributes["learnableSkill"] { learnableSkill = v }
        if let v = attributes["mostHated"] { mostHated = v }
        wantedGoods = (0..<3).compactMap { attributes["wantedGoods\($0)"] }
    }
}
