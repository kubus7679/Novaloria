import Foundation
import FreeColProtocol

/// A tile improvement present on a map tile (`<tileImprovement>`).
public struct TileImprovement: Sendable, Identifiable {
    public var id: String
    public var type: String?
    public var turns: Int
    public var magnitude: Int
    public var virtual: Bool
    public var style: String?

    public init(id: String, type: String?, turns: Int, magnitude: Int, virtual: Bool, style: String? = nil) {
        self.id = id
        self.type = type
        self.turns = turns
        self.magnitude = magnitude
        self.virtual = virtual
        self.style = style
    }
}

/// A natural resource present on a tile (`<resource>`).
public struct TileResource: Sendable, Identifiable {
    public var id: String
    public var type: String?
    public var quantity: Int

    public init(id: String, type: String?, quantity: Int) {
        self.id = id
        self.type = type
        self.quantity = quantity
    }

    public var displayName: String {
        guard let type else { return id }
        return type.split(separator: ".").last.map(String.init) ?? type
    }
}

public struct Tile: GameObject, Identifiable {
    public var id: String
    public var x: Int = 0
    public var y: Int = 0
    public var type: String?
    public var owner: String?
    public var owningSettlement: String?
    public var style: Int = 0
    public var region: String?
    public var moveToEurope: Bool = false
    public var highSeasCount: Int = -1
    public var settlement: String?  // colony or indianSettlement ID
    public var unitIds: [String] = []
    /// Improvements on the tile (roads, plowed, cleared forest, ...).
    public var improvements: [TileImprovement] = []
    /// Natural resources on the tile.
    public var resources: [TileResource] = []
    /// Lost city rumour present on the tile, if any.
    public var lostCityRumourId: String?
    public var lostCityRumourType: String?
    public var lostCityName: String?
    public var hasLostCityRumour: Bool = false

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        x = attributes.int("x")
        y = attributes.int("y")
        type = attributes["type"]
        owner = attributes["owner"]
        owningSettlement = attributes["owningSettlement"]
        style = attributes.int("style")
        region = attributes["region"]
        if attributes["moveToEurope"] != nil {
            moveToEurope = attributes.bool("moveToEurope")
        } else {
            moveToEurope = type.flatMap { game.specification?.tileTypes[$0]?.canMoveToEurope }
                ?? (type == "model.tile.highSeas")
        }
        highSeasCount = attributes.int("connected", default: -1)

        for child in children {
            switch child.tag {
            case "colony", "indianSettlement":
                settlement = child.attributes["id"]
            case "tileItemContainer":
                for item in child.children {
                    switch item.tag {
                    case "tileImprovement":
                        improvements.append(TileImprovement(
                            id: item.attributes["id"] ?? "",
                            type: item.attributes["type"],
                            turns: item.attributes.int("turns"),
                            magnitude: item.attributes.int("magnitude"),
                            virtual: item.attributes.bool("virtual", default: false),
                            style: item.attributes["style"]
                        ))
                    case "resource":
                        resources.append(TileResource(
                            id: item.attributes["id"] ?? "",
                            type: item.attributes["type"],
                            quantity: item.attributes.int("quantity")
                        ))
                    case "lostCityRumour":
                        hasLostCityRumour = true
                        lostCityRumourId = item.attributes["id"]
                        lostCityRumourType = item.attributes["type"]
                        lostCityName = item.attributes["name"] ?? item.attributes["id"]
                    default:
                        break
                    }
                }
            default:
                break
            }
        }
    }
}
