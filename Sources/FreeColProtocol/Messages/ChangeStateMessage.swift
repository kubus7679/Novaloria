import Foundation

public struct ChangeStateMessage: FreeColMessage {
    public static let tag = "changeState"

    public let state: String?
    public let unit: String?

    public init(
        state: String? = nil,
        unit: String? = nil
    ) {
        self.state = state
        self.unit = unit
    }

    public init(attributes: Attributes, children: Children) throws {
        self.state = attributes["state"]
        self.unit = attributes["unit"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = state { attrs["state"] = v }
        if let v = unit { attrs["unit"] = v }
        return (attrs, [])
    }
}
