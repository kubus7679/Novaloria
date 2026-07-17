import Foundation

public struct MissionaryMessage: FreeColMessage {
    public static let tag = "missionary"

    public let denounce: String?
    public let unit: String?
    public let direction: String?

    public init(
        denounce: String? = nil,
        unit: String? = nil,
        direction: String? = nil
    ) {
        self.denounce = denounce
        self.unit = unit
        self.direction = direction
    }

    public init(attributes: Attributes, children: Children) throws {
        self.denounce = attributes["denounce"]
        self.unit = attributes["unit"]
        self.direction = attributes["direction"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = denounce { attrs["denounce"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = direction { attrs["direction"] = v }
        return (attrs, [])
    }
}
