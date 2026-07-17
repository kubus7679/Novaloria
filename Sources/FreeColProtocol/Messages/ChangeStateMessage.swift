import Foundation

public struct ChangeStateMessage: FreeColMessage {
    public static let tag = "changeState"

    public let unit: String?
    public let state: String?

    public init(
        unit: String? = nil,
        state: String? = nil
    ) {
        self.unit = unit
        self.state = state
    }

    public init(attributes: Attributes, children: Children) throws {
        self.unit = attributes["unit"]
        self.state = attributes["state"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = unit { attrs["unit"] = v }
        if let v = state { attrs["state"] = v }
        return (attrs, [])
    }
}
