import Foundation

public struct AnimateAttackMessage: FreeColMessage {
    public static let tag = "animateAttack"

    public let attackerTile: String?
    public let defenderTile: String?
    public let defender: String?
    public let success: String?
    public let attacker: String?
    public let children: [ParsedMessage]

    public init(
        attackerTile: String? = nil,
        defenderTile: String? = nil,
        defender: String? = nil,
        success: String? = nil,
        attacker: String? = nil
    ) {
        self.attackerTile = attackerTile
        self.defenderTile = defenderTile
        self.defender = defender
        self.success = success
        self.attacker = attacker
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.attackerTile = attributes["attackerTile"]
        self.defenderTile = attributes["defenderTile"]
        self.defender = attributes["defender"]
        self.success = attributes["success"]
        self.attacker = attributes["attacker"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = attackerTile { attrs["attackerTile"] = v }
        if let v = defenderTile { attrs["defenderTile"] = v }
        if let v = defender { attrs["defender"] = v }
        if let v = success { attrs["success"] = v }
        if let v = attacker { attrs["attacker"] = v }
        return (attrs, [])
    }
}
