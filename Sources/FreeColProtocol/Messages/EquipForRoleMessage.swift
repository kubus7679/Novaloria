import Foundation

public struct EquipForRoleMessage: FreeColMessage {
    public static let tag = "equipForRole"

    public let role: String?
    public let unit: String?
    public let count: String?

    public init(
        role: String? = nil,
        unit: String? = nil,
        count: String? = nil
    ) {
        self.role = role
        self.unit = unit
        self.count = count
    }

    public init(attributes: Attributes, children: Children) throws {
        self.role = attributes["role"]
        self.unit = attributes["unit"]
        self.count = attributes["count"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = role { attrs["role"] = v }
        if let v = unit { attrs["unit"] = v }
        if let v = count { attrs["count"] = v }
        return (attrs, [])
    }
}
