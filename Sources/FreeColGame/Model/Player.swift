import Foundation
import FreeColProtocol

public enum PlayerType: String {
    case european = "EUROPEAN"
    case ref = "REF"
    case indian = "INDIAN"
    case undead = "UNDEAD"

    public init?(xmlValue: String) {
        switch xmlValue.lowercased() {
        case "european", "colonial":
            self = .european
        case "ref":
            self = .ref
        case "indian", "native":
            self = .indian
        case "undead":
            self = .undead
        default:
            return nil
        }
    }
}

public enum Stance: String {
    case uncontacted = "UNCONTACTED"
    case peace = "PEACE"
    case war = "WAR"
    case ceaseFire = "CEASE_FIRE"
    case alliance = "ALLIANCE"

    public init?(xmlValue: String) {
        switch xmlValue.uppercased() {
        case "UNCONTACTED":
            self = .uncontacted
        case "PEACE":
            self = .peace
        case "WAR":
            self = .war
        case "CEASE_FIRE":
            self = .ceaseFire
        case "ALLIANCE":
            self = .alliance
        default:
            return nil
        }
    }
}

/// A server model message (event log / turn report entry).
public struct ModelMessage: Sendable, Identifiable {
    public var id: String
    public var source: String?
    public var display: String?
    public var messageType: String?
    public var hasBeenDisplayed: Bool

    public init(id: String,
                source: String?,
                display: String?,
                messageType: String?,
                hasBeenDisplayed: Bool) {
        self.id = id
        self.source = source
        self.display = display
        self.messageType = messageType
        self.hasBeenDisplayed = hasBeenDisplayed
    }

    /// Best-effort label: the message key with any `model.message.` prefix removed.
    public var label: String {
        if let display, !display.isEmpty { return display }
        var text = id
        if let range = text.range(of: "model.message.") {
            text = String(text[range.upperBound...])
        }
        return text
    }
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
    /// Founding fathers already in the Continental Congress.
    public var foundingFathers: [String] = []
    /// Founding fathers currently offered for election.
    public var offeredFathers: [String] = []
    /// The father currently being elected (progress state).
    public var currentFather: String?
    /// Server model messages (event log / turn report).
    public var modelMessages: [ModelMessage] = []
    /// Tension (0-1000) toward other players, keyed by player id.
    public var tension: [String: Int] = [:]
    /// Players whose missions are banned.
    public var bannedMissions: Set<String> = []
    /// Abilities granted/removed via `featureChange`, keyed by ability id.
    public var abilities: [String: Bool] = [:]

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
                   let stance = Stance(xmlValue: v) {
                    stances[otherPlayerId] = stance
                }
            case "tradeRoute":
                if let route = try? TradeRoute(id: child.attributes["id"] ?? UUID().uuidString,
                                               attributes: child.attributes,
                                               children: child.children,
                                               game: game) {
                    game.addTradeRoute(route)
                }
            case "foundingFathers":
                foundingFathers = Player.listValues(child)
            case "offeredFathers":
                offeredFathers = Player.listValues(child)
            case "modelMessage":
                modelMessages.append(ModelMessage(
                    id: child.attributes["id"] ?? "",
                    source: child.attributes["source"],
                    display: child.attributes["display"],
                    messageType: child.attributes["messageType"],
                    hasBeenDisplayed: child.attributes.bool("hasBeenDisplayed", default: false)
                ))
            case "tension":
                if let playerId = child.attributes["player"] {
                    tension[playerId] = child.attributes.int("value")
                }
            case "banMissions":
                if let playerId = child.attributes["player"] {
                    bannedMissions.insert(playerId)
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
        if let v = attributes["playerType"], let pt = PlayerType(xmlValue: v) { playerType = pt }
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
        if let v = attributes["currentFather"] { currentFather = v }
    }

    /// Read a `<... xLength="n" x0="a" x1="b"/>` list element into an array.
    static func listValues(_ node: ParsedMessage) -> [String] {
        let count = node.attributes.int("xLength", default: 0)
        guard count > 0 else { return [] }
        var values: [String] = []
        for index in 0..<count {
            if let value = node.attributes["x\(index)"] {
                values.append(value)
            }
        }
        return values
    }
}
