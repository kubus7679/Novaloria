import Foundation
import FreeColProtocol

public enum PlayerType: String {
    case european = "EUROPEAN"
    case ref = "REF"
    case indian = "INDIAN"
    case undead = "UNDEAD"
}

public enum Stance: String {
    case uncontacted = "UNCONTACTED"
    case peace = "PEACE"
    case war = "WAR"
    case ceaseFire = "CEASE_FIRE"
    case alliance = "ALLIANCE"
}

public struct Player: GameObject, PartiallyUpdatable, Identifiable {
    public var id: String
    public var name: String?
    public var nationId: String?
    public var nationType: String?
    public var playerType: PlayerType = .european
    public var ai: Bool = false
    public var dead: Bool = false
    public var admin: Bool = false
    public var ready: Bool = false
    public var gold: Int = 0
    public var tax: Int = 0
    public var immigration: Int = 0
    public var liberty: Int = 0
    public var score: Int = 0
    public var newLandName: String?
    public var europe: Europe?
    public var market: Market?
    public var stances: [String: Stance] = [:]

    public var publicId: String { id }

    public init(id: String, attributes: Attributes, children: [ParsedMessage], game: Game) throws {
        self.id = id
        applyPartial(attributes: attributes)
        for child in children {
            switch child.tag {
            case "europe":
                europe = Europe(id: child.attributes["id"] ?? "\(id)-europe",
                                attributes: child.attributes,
                                children: child.children)
            case "market":
                market = Market(attributes: child.attributes, children: child.children)
            case "stance":
                // Stance map entries are serialized as <stance player=".." value=".."/> children.
                if let otherPlayerId = child.attributes["player"],
                   let v = child.attributes["value"],
                   let stance = Stance(rawValue: v) {
                    stances[otherPlayerId] = stance
                }
            case "tradeRoute":
                if let route = try? TradeRoute(id: child.attributes["id"] ?? UUID().uuidString,
                                               attributes: child.attributes,
                                               children: child.children,
                                               game: game) {
                    game.addTradeRoute(route)
                }
            default:
                break
            }
        }
    }

    public mutating func applyPartial(attributes: Attributes) {
        if let v = attributes["username"] { name = v }
        if let v = attributes["nationId"] { nationId = v }
        if let v = attributes["nationType"] { nationType = v }
        if let v = attributes["playerType"], let pt = PlayerType(rawValue: v) { playerType = pt }
        ai = attributes.bool("ai", default: ai)
        dead = attributes.bool("dead", default: dead)
        admin = attributes.bool("admin", default: admin)
        ready = attributes.bool("ready", default: ready)
        gold = attributes.int("gold", default: gold)
        tax = attributes.int("tax", default: tax)
        immigration = attributes.int("immigration", default: immigration)
        liberty = attributes.int("liberty", default: liberty)
        score = attributes.int("score", default: score)
        if let v = attributes["newLandName"] { newLandName = v }
    }
}
