import Foundation

public struct AttackRangedMessage: FreeColMessage {
    public static let tag = "attackRanged"

    public let unit: String?
    public let target: String?

    public init(
        unit: String? = nil,
        target: String? = nil
    ) {
        self.unit = unit
        self.target = target
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.target = attributes["target"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = target { attrs["target"] = v }
        return (attrs, [])
    }
}
