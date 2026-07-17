import Foundation

public struct IndianDemandMessage: FreeColMessage {
    public static let tag = "indianDemand"

    public let type: String?
    public let result: String?
    public let amount: String?
    public let colony: String?
    public let unit: String?

    public init(
        type: String? = nil,
        result: String? = nil,
        amount: String? = nil,
        colony: String? = nil,
        unit: String? = nil
    ) {
        self.type = type
        self.result = result
        self.amount = amount
        self.colony = colony
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.type = attributes["type"]
        self.result = attributes["result"]
        self.amount = attributes["amount"]
        self.colony = attributes["colony"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = type { attrs["type"] = v }
        if let v = result { attrs["result"] = v }
        if let v = amount { attrs["amount"] = v }
        if let v = colony { attrs["colony"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
