import Foundation

public struct SetStanceMessage: FreeColMessage {
    public static let tag = "setStance"

    public let first: String?
    public let second: String?
    public let stance: String?

    public init(
        first: String? = nil,
        second: String? = nil,
        stance: String? = nil
    ) {
        self.first = first
        self.second = second
        self.stance = stance
    }

    public init(attributes: Attributes, children: Children) throws {
        self.first = attributes["first"]
        self.second = attributes["second"]
        self.stance = attributes["stance"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = first { attrs["first"] = v }
        if let v = second { attrs["second"] = v }
        if let v = stance { attrs["stance"] = v }
        return (attrs, [])
    }
}
