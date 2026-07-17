import Foundation

public struct UnloadGoodsMessage: FreeColMessage {
    public static let tag = "unloadGoods"

    public let carrier: String?
    public let amount: String?
    public let type: String?

    public init(
        carrier: String? = nil,
        amount: String? = nil,
        type: String? = nil
    ) {
        self.carrier = carrier
        self.amount = amount
        self.type = type
    }

    public init(attributes: Attributes, children: Children) throws {
        self.carrier = attributes["carrier"]
        self.amount = attributes["amount"]
        self.type = attributes["type"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = carrier { attrs["carrier"] = v }
        if let v = amount { attrs["amount"] = v }
        if let v = type { attrs["type"] = v }
        return (attrs, [])
    }
}
