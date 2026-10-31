import Foundation
import FreeColProtocol

public enum UnitState: String {
    case active = "ACTIVE"
    case sentry = "SENTRY"
    case fortifying = "FORTIFYING"
    case fortified = "FORTIFIED"
    case sailing = "SAILING"
    case inColony = "IN_COLONY"
    case improving = "IMPROVING"
    case toEurope = "TO_EUROPE"
    case toAmerica = "TO_AMERICA"
    case skipped = "SKIPPED"
}

public struct Unit: GameObject, PartiallyUpdatable, Identifiable {
    public var id: String
    public var name: String?
    public var unitType: String?
    public var owner: String?
    public var nationality: String?
    public var location: String?
    public var entryLocation: String?
    public var movesLeft: Int = 0
    public var state: UnitState = .active
    public var role: String?
    public var roleCount: Int = 0
    public var experience: Int = 0
    public var hitPoints: Int = 0
    public var treasureAmount: Int = 0
    public var workType: String?
    public var destination: String?
    public var tradeRoute: String?
    public var currentStop: Int = 0
    public var student: String?
    public var teacher: String?
    public var workImprovementType: String?
    /// Remaining work turns for a pioneer improvement or high-seas sail.
    public var workLeft: Int = 0
    /// Goods carried by a carrier, keyed by goods type id (`<goodsContainer>`).
    public var goods: [String: Int] = [:]

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
        for child in children where child.tag == "goodsContainer" {
            for storage in child.children where storage.tag == "storedGoods" {
                for goodsNode in storage.children where goodsNode.tag == "goods" {
                    if let type = goodsNode.attributes["type"] {
                        goods[type] = goodsNode.attributes.int("amount")
                    }
                }
            }
        }
    }

    public mutating func applyPartial(attributes: Attributes) {
        if let v = attributes["name"] { name = v }
        if let v = attributes["unitType"] { unitType = v }
        if let v = attributes["owner"] { owner = v }
        if let v = attributes["nationality"] { nationality = v }
        if let v = attributes["location"] { location = v }
        if let v = attributes["entryLocation"] { entryLocation = v }
        movesLeft = attributes.int("movesLeft", default: movesLeft)
        if let v = attributes["state"], let s = UnitState(rawValue: v) { state = s }
        if let v = attributes["role"] { role = v }
        roleCount = attributes.int("roleCount", default: roleCount)
        experience = attributes.int("experience", default: experience)
        hitPoints = attributes.int("hitPoints", default: hitPoints)
        treasureAmount = attributes.int("treasureAmount", default: treasureAmount)
        if let v = attributes["workType"] { workType = v }
        if let v = attributes["destination"] { destination = v }
        if let v = attributes["tradeRoute"] { tradeRoute = v }
        currentStop = attributes.int("currentStop", default: currentStop)
        if let v = attributes["student"] { student = v }
        if let v = attributes["teacher"] { teacher = v }
        if let v = attributes["workImprovementType"] { workImprovementType = v }
        workLeft = attributes.int("workLeft", default: workLeft)
    }
}
