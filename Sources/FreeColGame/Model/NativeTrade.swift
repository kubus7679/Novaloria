import Foundation
import FreeColProtocol

/// A goods stack offered during a native trade session.
public struct NativeTradeItem: Identifiable, Equatable {
    public var id: String {
        goodsType ?? "\(source ?? "?")-\(amount)"
    }
    public var goodsType: String?
    public var amount: Int
    public var goodsLocation: String?
    /// 0 = unset, -1 = invalid, >0 = valid price.
    public var price: Int
    public var haggleCount: Int
    public var source: String?
    public var destination: String?

    public var priceIsValid: Bool { price > 0 }

    public init(attributes: Attributes, goods: ParsedMessage?) {
        self.price = attributes.int("price", default: -1)
        self.haggleCount = attributes.int("haggleCount", default: 0)
        self.source = attributes["source"]
        self.destination = attributes["destination"]
        self.goodsType = goods?.attributes["type"]
        self.amount = goods.map { $0.attributes.int("amount", default: 0) } ?? 0
        self.goodsLocation = goods?.attributes["location"]
    }

    public init(goodsType: String?, amount: Int, price: Int, haggleCount: Int = 0,
                source: String? = nil, destination: String? = nil,
                goodsLocation: String? = nil) {
        self.goodsType = goodsType
        self.amount = amount
        self.goodsLocation = goodsLocation
        self.price = price
        self.haggleCount = haggleCount
        self.source = source
        self.destination = destination
    }

    /// Serialize this item as a `<nativeTradeItem><goods .../></nativeTradeItem>` node.
    public func toMessage() -> ParsedMessage {
        var attributes: Attributes = [
            "id": "model.tradeItem.goods.name",
            "price": "\(price)",
            "haggleCount": "\(haggleCount)"
        ]
        if let source { attributes["source"] = source }
        if let destination { attributes["destination"] = destination }
        var children: [ParsedMessage] = []
        if let goodsType {
            var goodsAttributes: Attributes = [
                "type": goodsType,
                "amount": "\(amount)"
            ]
            if let goodsLocation { goodsAttributes["location"] = goodsLocation }
            children.append(ParsedMessage(
                tag: "goods",
                attributes: goodsAttributes,
                children: []
            ))
        }
        return ParsedMessage(tag: "nativeTradeItem", attributes: attributes, children: children)
    }
}

/// Parsed state of a `nativeTrade` session, as sent by the server/native AI.
public struct NativeTradeSession {
    public var unitId: String?
    public var settlementId: String?
    public var buy: Bool
    public var sell: Bool
    public var gift: Bool
    public var count: Int
    /// Goods the unit can buy from the settlement.
    public var settlementToUnit: [NativeTradeItem]
    /// Goods the unit can sell to the settlement.
    public var unitToSettlement: [NativeTradeItem]
    /// The item currently under negotiation (haggle target).
    public var item: NativeTradeItem?

    public init(
        unitId: String? = nil,
        settlementId: String? = nil,
        buy: Bool = true,
        sell: Bool = true,
        gift: Bool = true,
        count: Int = 0,
        settlementToUnit: [NativeTradeItem] = [],
        unitToSettlement: [NativeTradeItem] = [],
        item: NativeTradeItem? = nil
    ) {
        self.unitId = unitId
        self.settlementId = settlementId
        self.buy = buy
        self.sell = sell
        self.gift = gift
        self.count = count
        self.settlementToUnit = settlementToUnit
        self.unitToSettlement = unitToSettlement
        self.item = item
    }

    /// Parse the `<nativeTrade>` child of a `nativeTrade` message.
    public init(nativeTradeChild child: ParsedMessage?) {
        guard let child else {
            self.init()
            return
        }
        var settlementToUnit: [NativeTradeItem] = []
        var unitToSettlement: [NativeTradeItem] = []
        var item: NativeTradeItem?
        for node in child.children {
            switch node.tag {
            case "settlementToUnit":
                settlementToUnit = node.children
                    .filter { $0.tag == "nativeTradeItem" }
                    .map { Self.parseItem($0) }
            case "unitToSettlement":
                unitToSettlement = node.children
                    .filter { $0.tag == "nativeTradeItem" }
                    .map { Self.parseItem($0) }
            case "nativeTradeItem":
                item = Self.parseItem(node)
            default:
                break
            }
        }
        self.init(
            unitId: child.attributes["unit"],
            settlementId: child.attributes["settlement"],
            buy: child.attributes.bool("buy", default: true),
            sell: child.attributes.bool("sell", default: true),
            gift: child.attributes.bool("gift", default: true),
            count: child.attributes.int("count", default: 0),
            settlementToUnit: settlementToUnit,
            unitToSettlement: unitToSettlement,
            item: item
        )
    }

    private static func parseItem(_ node: ParsedMessage) -> NativeTradeItem {
        NativeTradeItem(
            attributes: node.attributes,
            goods: node.children.first { $0.tag == "goods" }
        )
    }

    /// Serialize the session as the inner `<nativeTrade>` node.
    public func toInnerMessage() -> ParsedMessage {
        var attributes: Attributes = [
            "buy": buy ? "true" : "false",
            "sell": sell ? "true" : "false",
            "gift": gift ? "true" : "false",
            "count": "\(count)"
        ]
        if let unitId { attributes["unit"] = unitId }
        if let settlementId { attributes["settlement"] = settlementId }
        if let unitId, let settlementId {
            attributes["id"] = "\(unitId)-\(settlementId)"
        }
        var children: [ParsedMessage] = [
            ParsedMessage(tag: "settlementToUnit", attributes: [:], children: settlementToUnit.map { $0.toMessage() }),
            ParsedMessage(tag: "unitToSettlement", attributes: [:], children: unitToSettlement.map { $0.toMessage() })
        ]
        if let item { children.append(item.toMessage()) }
        return ParsedMessage(tag: "nativeTrade", attributes: attributes, children: children)
    }

    /// Build the outer `<nativeTrade action=...>` request wrapper.
    public func toMessage(action: String, item: NativeTradeItem?) -> ParsedMessage {
        var session = self
        if let item { session.item = item }
        return ParsedMessage(
            tag: "nativeTrade",
            attributes: ["action": action],
            children: [session.toInnerMessage()]
        )
    }

    /// Merge fresh pricing/state from a newer server payload.
    public mutating func merge(from newer: NativeTradeSession) {
        if !newer.settlementToUnit.isEmpty { settlementToUnit = newer.settlementToUnit }
        if !newer.unitToSettlement.isEmpty { unitToSettlement = newer.unitToSettlement }
        if let item = newer.item { self.item = item }
        buy = newer.buy
        sell = newer.sell
        gift = newer.gift
        count = newer.count
    }
}
