import Foundation

public struct UnloadGoodsMessage: FreeColMessage {
    public static let tag = "unloadGoods"

    public let carrier: String?
    public let type: String?
    public let amount: String?

    public init(
        carrier: String? = nil,
        type: String? = nil,
        amount: String? = nil
    ) {
        self.carrier = carrier
        self.type = type
        self.amount = amount
    }

    public init(attributes: Attributes, children: Children) throws {
        self.carrier = attributes["carrier"]
        self.type = attributes["type"]
        self.amount = attributes["amount"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = carrier { attrs["carrier"] = v }
        if let v = type { attrs["type"] = v }
        if let v = amount { attrs["amount"] = v }
        return (attrs, [])
    }
}
