import Foundation

public struct IndianDemandMessage: FreeColMessage {
    public static let tag = "indianDemand"

    public let type: String?
    public let result: String?
    public let unit: String?
    public let colony: String?
    public let amount: String?

    public init(
        type: String? = nil,
        result: String? = nil,
        unit: String? = nil,
        colony: String? = nil,
        amount: String? = nil
    ) {
        self.type = type
        self.result = result
        self.unit = unit
        self.colony = colony
        self.amount = amount
    }

    public init(attributes: Attributes, children: Children) throws {
        self.type = attributes["type"]
        self.result = attributes["result"]
        self.unit = attributes["unit"]
        self.colony = attributes["colony"]
        self.amount = attributes["amount"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = type { attrs["type"] = v }
        if let v = result { attrs["result"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = colony { attrs["colony"] = v }
        if let v = amount { attrs["amount"] = v }
        return (attrs, [])
    }
}
