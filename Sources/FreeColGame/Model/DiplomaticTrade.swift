import Foundation
import FreeColProtocol

/// A single clause within a `<diplomaticTrade>` agreement.
public struct DiplomaticTradeClause: Identifiable, Equatable {
    public let id: Int
    public let tag: String
    public let attributes: Attributes
    public let goodsType: String?
    public let amount: Int
    public let summary: String

    public init(index: Int, node: ParsedMessage) {
        self.id = index
        self.tag = node.tag
        self.attributes = node.attributes
        let goods = node.children.first { $0.tag == "goods" }
        self.goodsType = goods?.attributes["type"]
        self.amount = goods.map { $0.attributes.int("amount", default: 0) }
            ?? node.attributes.int("amount", default: 0)
        self.summary = Self.describe(node: node, goodsType: goodsType, amount: amount)
    }

    private static func describe(node: ParsedMessage, goodsType: String?, amount: Int) -> String {
        let from = node.attributes["source"]
        let to = node.attributes["destination"]
        let route = (from != nil || to != nil) ? " [\(from ?? "?") → \(to ?? "?")]" : ""
        switch node.tag {
        case "goldTradeItem":
            return "Gold \(node.attributes["gold"] ?? "?")\(route)"
        case "goodsTradeItem":
            return "\(goodsType ?? "goods") x\(amount)\(route)"
        case "colonyTradeItem":
            return "Colony \(node.attributes["colonyName"] ?? node.attributes["colony"] ?? "?")\(route)"
        case "unitTradeItem":
            return "Unit \(node.attributes["unit"] ?? "?")\(route)"
        case "stanceTradeItem":
            return "Stance \(node.attributes["stance"] ?? "?")\(route)"
        case "inciteTradeItem":
            return "Incite \(node.attributes["victim"] ?? "?")\(route)"
        default:
            return node.tag
        }
    }
}

/// Parsed `<diplomaticTrade>` proposal attached to a `diplomacy` message.
public struct DiplomaticTradeProposal {
    public let context: String?
    public let sender: String?
    public let recipient: String?
    public let status: String?
    public let version: Int
    /// The raw `<diplomaticTrade>` node, echoed back when answering.
    public let raw: ParsedMessage
    public let clauses: [DiplomaticTradeClause]

    public var isProposal: Bool { status == nil || status == "PROPOSE_TRADE" }

    public init(raw: ParsedMessage) {
        self.raw = raw
        self.context = raw.attributes["context"]?.uppercased()
        self.sender = raw.attributes["sender"]
        self.recipient = raw.attributes["recipient"]
        self.status = raw.attributes["status"]?.uppercased()
        self.version = raw.attributes.int("version", default: 0)
        self.clauses = raw.children.enumerated().map { index, node in
            DiplomaticTradeClause(index: index, node: node)
        }
    }
}

/// Clause kinds the client can build for a counter-proposal.
public enum DiplomaticClauseKind: String, CaseIterable, Identifiable, Sendable {
    case gold
    case goods
    case colony
    case stance
    case unit
    case incite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gold: return "Gold"
        case .goods: return "Goods"
        case .colony: return "Colony"
        case .stance: return "Stance"
        case .unit: return "Unit"
        case .incite: return "Incite"
        }
    }

    /// The trade-item `id` used by the Java client (`model.tradeItem.*`).
    public var tradeItemId: String { "model.tradeItem.\(rawValue)" }

    /// XML tag for the clause node.
    public var tag: String { "\(rawValue)TradeItem" }

    public init?(clauseTag: String) {
        guard clauseTag.hasSuffix("TradeItem") else { return nil }
        let base = String(clauseTag.dropLast("TradeItem".count))
        self.init(rawValue: base)
    }
}

/// Editable clause used by the diplomacy counter-proposal builder.
public struct DiplomaticClauseDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: DiplomaticClauseKind
    /// True when the local player gives this item, false when the other does.
    public var weGive: Bool
    public var goldAmount: Int
    public var goodsType: String
    public var goodsAmount: Int
    public var colonyId: String
    public var colonyName: String
    public var stance: String
    public var unitId: String
    public var victimId: String

    public init(id: UUID = UUID(),
                kind: DiplomaticClauseKind,
                weGive: Bool = true,
                goldAmount: Int = 100,
                goodsType: String = "",
                goodsAmount: Int = 10,
                colonyId: String = "",
                colonyName: String = "",
                stance: String = "PEACE",
                unitId: String = "",
                victimId: String = "") {
        self.id = id
        self.kind = kind
        self.weGive = weGive
        self.goldAmount = goldAmount
        self.goodsType = goodsType
        self.goodsAmount = goodsAmount
        self.colonyId = colonyId
        self.colonyName = colonyName
        self.stance = stance
        self.unitId = unitId
        self.victimId = victimId
    }

    /// Reconstruct a draft from a server proposal clause, if supported.
    public init?(clause: DiplomaticTradeClause, ourPlayerId: String) {
        guard let kind = DiplomaticClauseKind(clauseTag: clause.tag) else { return nil }
        let source = clause.attributes["source"]
        self.init(
            kind: kind,
            weGive: source == ourPlayerId,
            goldAmount: clause.attributes.int("gold", default: 100),
            goodsType: clause.goodsType ?? "",
            goodsAmount: clause.amount,
            colonyId: clause.attributes["colony"] ?? "",
            colonyName: clause.attributes["colonyName"] ?? "",
            stance: clause.attributes["stance"] ?? "PEACE",
            unitId: clause.attributes["unit"] ?? "",
            victimId: clause.attributes["victim"] ?? ""
        )
    }
}
