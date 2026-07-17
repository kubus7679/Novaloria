import Foundation

public struct AnimateAttackMessage: FreeColMessage {
    public static let tag = "animateAttack"

    public let success: String?
    public let defenderTile: String?
    public let defender: String?
    public let attacker: String?
    public let attackerTile: String?
    public let children: [ParsedMessage]

    public init(
        success: String? = nil,
        defenderTile: String? = nil,
        defender: String? = nil,
        attacker: String? = nil,
        attackerTile: String? = nil
    ) {
        self.success = success
        self.defenderTile = defenderTile
        self.defender = defender
        self.attacker = attacker
        self.attackerTile = attackerTile
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.success = attributes["success"]
        self.defenderTile = attributes["defenderTile"]
        self.defender = attributes["defender"]
        self.attacker = attributes["attacker"]
        self.attackerTile = attributes["attackerTile"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = success { attrs["success"] = v }
        if let v = defenderTile { attrs["defenderTile"] = v }
        if let v = defender { attrs["defender"] = v }
        if let v = attacker { attrs["attacker"] = v }
        if let v = attackerTile { attrs["attackerTile"] = v }
        return (attrs, [])
    }
}
