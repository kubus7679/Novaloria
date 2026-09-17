import Foundation
import FreeColProtocol

/// A tile improvement present on a map tile (`<tileImprovement>`).
public struct TileImprovement: Sendable, Identifiable {
    public var id: String
    public var type: String?
    public var turns: Int
    public var magnitude: Int
    public var virtual: Bool

    public init(id: String, type: String?, turns: Int, magnitude: Int, virtual: Bool) {
        self.id = id
        self.type = type
        self.turns = turns
        self.magnitude = magnitude
        self.virtual = virtual
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

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        x = attributes.int("x")
        y = attributes.int("y")
        type = attributes["type"]
        owner = attributes["owner"]
        owningSettlement = attributes["owningSettlement"]
        style = attributes.int("style")
        region = attributes["region"]
        moveToEurope = attributes.bool("moveToEurope")
        highSeasCount = attributes.int("connected", default: -1)

        for child in children {
            switch child.tag {
            case "colony", "indianSettlement":
                settlement = child.attributes["id"]
            case "tileItemContainer":
                for item in child.children where item.tag == "tileImprovement" {
                    improvements.append(TileImprovement(
                        id: item.attributes["id"] ?? "",
                        type: item.attributes["type"],
                        turns: item.attributes.int("turns"),
                        magnitude: item.attributes.int("magnitude"),
                        virtual: item.attributes.bool("virtual", default: false)
                    ))
                }
            default:
                break
            }
        }
    }
}
