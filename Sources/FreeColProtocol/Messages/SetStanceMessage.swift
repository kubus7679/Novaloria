import Foundation

public struct SetStanceMessage: FreeColMessage {
    public static let tag = "setStance"

    public let stance: String?
    public let first: String?
    public let second: String?

    public init(
        stance: String? = nil,
        first: String? = nil,
        second: String? = nil
    ) {
        self.stance = stance
        self.first = first
        self.second = second
    }

    public init(attributes: Attributes, children: Children) throws {
        self.stance = attributes["stance"]
        self.first = attributes["first"]
        self.second = attributes["second"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = stance { attrs["stance"] = v }
        if let v = first { attrs["first"] = v }
        if let v = second { attrs["second"] = v }
        return (attrs, [])
    }
}
