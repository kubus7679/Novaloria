import Foundation
import FreeColProtocol

/// A recruitable unit offer in Europe, as published in `<recruit>` children of `<europe>`.
public struct Recruitable: Identifiable {
    public var id: String { unitType ?? "" }
    public var unitType: String?
    public var role: String?
    public var number: Int = 1

    public init(attributes: Attributes) {
        unitType = attributes["id"]
        role = attributes["role"]
        number = attributes.int("number", default: 1)
    }
}

/// Europe location of a player, as published in `<europe>` children of `<player>`.
public struct Europe: Identifiable {
    public var id: String
    public var owner: String?
    public var recruitPrice: Int = 0
    public var recruitLowerCap: Int = 0
    public var recruitable: [Recruitable] = []
    /// Unit purchase prices, keyed by unit type id (from `<unitPrice unitType= price=>`).
    public var unitPrices: [String: Int] = [:]

    public init(id: String, attributes: Attributes, children: [ParsedMessage] = []) {
        self.id = id
        owner = attributes["owner"]
        recruitPrice = attributes.int("recruitPrice", default: 0)
        recruitLowerCap = attributes.int("recruitLowerCap", default: 0)
        for child in children {
            switch child.tag {
            case "recruit":
                recruitable.append(Recruitable(attributes: child.attributes))
            case "unitPrice":
                if let unitType = child.attributes["unitType"] {
                    unitPrices[unitType] = child.attributes.int("price", default: 0)
                }
            default:
                break
            }
        }
    }

    /// Price for a given unit type, falling back to the recruit price.
    public func price(for unitType: String?) -> Int {
        guard let unitType else { return recruitPrice }
        return unitPrices[unitType] ?? recruitPrice
    }
}

/// Per-goods market entry, as published in `<marketData>` children of `<market>`.
public struct MarketData: Identifiable {
    public var id: String { goodsType ?? "" }
    public var goodsType: String?
    public var amount: Int = 0
    public var initialPrice: Int = 0
    public var arrears: Int = 0
    public var sales: Int = 0
    public var incomeAfterTaxes: Int = 0
    public var incomeBeforeTaxes: Int = 0
    public var traded: Bool = false

    public init(attributes: Attributes) {
        goodsType = attributes["goods-type"]
        amount = attributes.int("amount", default: 0)
        initialPrice = attributes.int("initialPrice", default: 0)
        arrears = attributes.int("arrears", default: 0)
        sales = attributes.int("sales", default: 0)
        incomeAfterTaxes = attributes.int("incomeAfterTaxes", default: 0)
        incomeBeforeTaxes = attributes.int("incomeBeforeTaxes", default: 0)
        traded = attributes.bool("traded", default: false)
    }
}

/// Client-side market price calculation, mirroring `MarketData.price()` in the
/// Java client. The server only serializes `amount` + `initialPrice`; the buy
/// and sale prices are derived from the goods-type market reference values.
public enum MarketPricing {
    public static let minimumPrice = 1
    public static let maximumPrice = 19

    /// Returns `(costToBuy, paidForSale)` for a market entry.
    ///
    /// This reproduces the first-pass of `MarketData.price()` (the clamping
    /// history is server-side state the client does not track).
    public static func prices(amount: Int,
                              initialPrice: Int,
                              info: GoodsTypeInfo?) -> (costToBuy: Int, paidForSale: Int) {
        guard let info, info.isStorable else { return (0, 0) }
        let referenceAmount = info.marketInitialAmount > 0
            ? info.marketInitialAmount
            : info.marketInitialPrice
        let effectiveAmount = amount > 0 ? amount : 1
        let diff = info.priceDifference
        let amountPrice = Double(initialPrice) * (Double(referenceAmount) / Double(effectiveAmount))
        var salePrice = Int(amountPrice.rounded())
        var buyPrice = salePrice + diff

        // Work-around to limit prices of new-world goods and their products.
        let isNewWorld = info.isNewWorldGoods
            || (info.madeFrom.flatMap { $0.contains("newWorld") } ?? false)
        if salePrice > initialPrice + 2, isNewWorld {
            salePrice = initialPrice + 2
            buyPrice = salePrice + diff
        }

        // Clamp extremes.
        if buyPrice > maximumPrice {
            buyPrice = maximumPrice
            salePrice = buyPrice - diff
        } else if salePrice < minimumPrice {
            salePrice = minimumPrice
            buyPrice = salePrice + diff
        }

        return (buyPrice, salePrice)
    }

    /// Prices for a market data entry using the specification.
    public static func prices(for entry: MarketData,
                              specification: Specification?) -> (costToBuy: Int, paidForSale: Int) {
        let info = specification?.goodsTypes[entry.goodsType ?? ""]
        return prices(amount: entry.amount,
                      initialPrice: entry.initialPrice,
                      info: info)
    }
}

/// Player market with prices, as published in `<market>` children of `<player>`.
public struct Market {
    public var owner: String?
    public var data: [String: MarketData] = [:]

    public init(attributes: Attributes, children: [ParsedMessage]) {
        owner = attributes["owner"]
        for child in children where child.tag == "marketData" {
            let entry = MarketData(attributes: child.attributes)
            if let type = entry.goodsType {
                data[type] = entry
            }
        }
    }

    public func entry(for goodsType: String?) -> MarketData? {
        guard let goodsType else { return nil }
        return data[goodsType]
    }
}