import Foundation

public struct PayArrearsMessage: FreeColMessage {
    public static let tag = "payArrears"

    public let goodsType: String?

    public init(
        goodsType: String? = nil
    ) {
        self.goodsType = goodsType
    }

    public init(attributes: Attributes, children: Children) throws {
        self.goodsType = attributes["goodsType"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = goodsType { attrs["goodsType"] = v }
        return (attrs, [])
    }
}
