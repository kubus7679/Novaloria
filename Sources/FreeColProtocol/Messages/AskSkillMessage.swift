import Foundation

public struct AskSkillMessage: FreeColMessage {
    public static let tag = "askSkill"

    public let direction: String?
    public let unit: String?

    public init(
        direction: String? = nil,
        unit: String? = nil
    ) {
        self.direction = direction
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.direction = attributes["direction"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = direction { attrs["direction"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
