import Foundation

public struct DisbandUnitMessage: FreeColMessage {
    public static let tag = "disbandUnit"

    public let unit: String?

    public init(
        unit: String? = nil
    ) {
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
