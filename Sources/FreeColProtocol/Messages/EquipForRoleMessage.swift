import Foundation

public struct EquipForRoleMessage: FreeColMessage {
    public static let tag = "equipForRole"

    public let role: String?
    public let count: String?
    public let unit: String?

    public init(
        role: String? = nil,
        count: String? = nil,
        unit: String? = nil
    ) {
        self.role = role
        self.count = count
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.role = attributes["role"]
        self.count = attributes["count"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = role { attrs["role"] = v }
        if let v = count { attrs["count"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
