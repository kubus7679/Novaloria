import Foundation

public struct MissionaryMessage: FreeColMessage {
    public static let tag = "missionary"

    public let direction: String?
    public let unit: String?
    public let denounce: String?

    public init(
        direction: String? = nil,
        unit: String? = nil,
        denounce: String? = nil
    ) {
        self.direction = direction
        self.unit = unit
        self.denounce = denounce
    }

    public init(attributes: Attributes, children: Children) throws {
        self.direction = attributes["direction"]
        self.unit = attributes["unit"]
        self.denounce = attributes["denounce"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = direction { attrs["direction"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = denounce { attrs["denounce"] = v }
        return (attrs, [])
    }
}
