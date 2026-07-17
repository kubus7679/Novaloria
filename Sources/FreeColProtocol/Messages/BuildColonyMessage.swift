import Foundation

public struct BuildColonyMessage: FreeColMessage {
    public static let tag = "buildColony"

    public let unit: String?
    public let name: String?

    public init(
        unit: String? = nil,
        name: String? = nil
    ) {
        self.unit = unit
        self.name = name
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.name = attributes["name"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = name { attrs["name"] = v }
        return (attrs, [])
    }
}
