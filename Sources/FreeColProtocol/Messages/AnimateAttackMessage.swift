import Foundation

public struct AnimateAttackMessage: FreeColMessage {
    public static let tag = "animateAttack"

    public let defenderTile: String?
    public let success: String?
    public let defender: String?
    public let attackerTile: String?
    public let attacker: String?
    public let children: [ParsedMessage]

    public init(
        defenderTile: String? = nil,
        success: String? = nil,
        defender: String? = nil,
        attackerTile: String? = nil,
        attacker: String? = nil
    ) {
        self.defenderTile = defenderTile
        self.success = success
        self.defender = defender
        self.attackerTile = attackerTile
        self.attacker = attacker
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.defenderTile = attributes["defenderTile"]
        self.success = attributes["success"]
        self.defender = attributes["defender"]
        self.attackerTile = attributes["attackerTile"]
        self.attacker = attributes["attacker"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = defenderTile { attrs["defenderTile"] = v }
        if let v = success { attrs["success"] = v }
        if let v = defender { attrs["defender"] = v }
        if let v = attackerTile { attrs["attackerTile"] = v }
        if let v = attacker { attrs["attacker"] = v }
        return (attrs, [])
    }
}
