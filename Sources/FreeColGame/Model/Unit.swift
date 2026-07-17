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
    public var movesLeft: Int = 0
    public var state: UnitState = .active
    public var role: String?
    public var roleCount: Int = 0
    public var hitPoints: Int = 0
    public var treasureAmount: Int = 0
    public var workType: String?
    public var destination: String?
    public var tradeRoute: String?
    public var currentStop: Int = 0
    public var student: String?
    public var teacher: String?
    public var workImprovementType: String?

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
    }

    public mutating func applyPartial(attributes: Attributes) {
        if let v = attributes["name"] { name = v }
        if let v = attributes["unitType"] { unitType = v }
        if let v = attributes["owner"] { owner = v }
        if let v = attributes["nationality"] { nationality = v }
        if let v = attributes["location"] { location = v }
        movesLeft = attributes.int("movesLeft", default: movesLeft)
        if let v = attributes["state"], let s = UnitState(rawValue: v) { state = s }
        if let v = attributes["role"] { role = v }
        roleCount = attributes.int("roleCount", default: roleCount)
        hitPoints = attributes.int("hitPoints", default: hitPoints)
        treasureAmount = attributes.int("treasureAmount", default: treasureAmount)
        if let v = attributes["workType"] { workType = v }
        if let v = attributes["destination"] { destination = v }
        if let v = attributes["tradeRoute"] { tradeRoute = v }
        currentStop = attributes.int("currentStop", default: currentStop)
        if let v = attributes["student"] { student = v }
        if let v = attributes["teacher"] { teacher = v }
        if let v = attributes["workImprovementType"] { workImprovementType = v }
    }
}
