import Foundation

public struct IndianDemandMessage: FreeColMessage {
    public static let tag = "indianDemand"

    public let colony: String?
    public let type: String?
    public let unit: String?
    public let amount: String?
    public let result: String?

    public init(
        colony: String? = nil,
        type: String? = nil,
        unit: String? = nil,
        amount: String? = nil,
        result: String? = nil
    ) {
        self.colony = colony
        self.type = type
        self.unit = unit
        self.amount = amount
        self.result = result
    }

    public init(attributes: Attributes, children: Children) throws {
        self.colony = attributes["colony"]
        self.type = attributes["type"]
        self.unit = attributes["unit"]
        self.amount = attributes["amount"]
        self.result = attributes["result"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = colony { attrs["colony"] = v }
        if let v = type { attrs["type"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = amount { attrs["amount"] = v }
        if let v = result { attrs["result"] = v }
        return (attrs, [])
    }
}
