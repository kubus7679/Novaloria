import Foundation

public struct LoadGoodsMessage: FreeColMessage {
    public static let tag = "loadGoods"

    public let carrier: String?
    public let location: String?
    public let type: String?
    public let amount: String?

    public init(
        carrier: String? = nil,
        location: String? = nil,
        type: String? = nil,
        amount: String? = nil
    ) {
        self.carrier = carrier
        self.location = location
        self.type = type
        self.amount = amount
    }

    public init(attributes: Attributes, children: Children) throws {
        self.carrier = attributes["carrier"]
        self.location = attributes["location"]
        self.type = attributes["type"]
        self.amount = attributes["amount"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = carrier { attrs["carrier"] = v }
        if let v = location { attrs["location"] = v }
        if let v = type { attrs["type"] = v }
        if let v = amount { attrs["amount"] = v }
        return (attrs, [])
    }
}
