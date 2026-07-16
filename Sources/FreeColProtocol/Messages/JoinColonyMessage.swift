import Foundation

public struct JoinColonyMessage: FreeColMessage {
    public static let tag = "joinColony"

    public let colony: String?
    public let unit: String?

    public init(
        colony: String? = nil,
        unit: String? = nil
    ) {
        self.colony = colony
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.colony = attributes["colony"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = colony { attrs["colony"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
