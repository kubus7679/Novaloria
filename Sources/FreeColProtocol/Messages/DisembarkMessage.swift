import Foundation

public struct DisembarkMessage: FreeColMessage {
    public static let tag = "disembark"

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
