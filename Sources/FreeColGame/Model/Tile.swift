import Foundation
import FreeColProtocol

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
            if child.tag == "colony" || child.tag == "indianSettlement" {
                settlement = child.attributes["id"]
            }
        }
    }
}
