import Foundation

public struct MissionaryMessage: FreeColMessage {
    public static let tag = "missionary"

    public let unit: String?
    public let direction: String?
    public let denounce: String?

    public init(
        unit: String? = nil,
        direction: String? = nil,
        denounce: String? = nil
    ) {
        self.unit = unit
        self.direction = direction
        self.denounce = denounce
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.direction = attributes["direction"]
        self.denounce = attributes["denounce"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = direction { attrs["direction"] = v }
        if let v = denounce { attrs["denounce"] = v }
        return (attrs, [])
    }
}
