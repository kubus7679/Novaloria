import Foundation

public struct NativeGiftMessage: FreeColMessage {
    public static let tag = "nativeGift"

    public let unit: String?
    public let colony: String?

    public init(
        unit: String? = nil,
        colony: String? = nil
    ) {
        self.unit = unit
        self.colony = colony
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.colony = attributes["colony"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = colony { attrs["colony"] = v }
        return (attrs, [])
    }
}
