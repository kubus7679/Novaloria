import Foundation

public struct BuildColonyMessage: FreeColMessage {
    public static let tag = "buildColony"

    public let name: String?
    public let unit: String?

    public init(
        name: String? = nil,
        unit: String? = nil
    ) {
        self.name = name
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.name = attributes["name"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = name { attrs["name"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
