import Foundation

public struct SetStanceMessage: FreeColMessage {
    public static let tag = "setStance"

    public let second: String?
    public let stance: String?
    public let first: String?

    public init(
        second: String? = nil,
        stance: String? = nil,
        first: String? = nil
    ) {
        self.second = second
        self.stance = stance
        self.first = first
    }

    public init(attributes: Attributes, children: Children) throws {
        self.second = attributes["second"]
        self.stance = attributes["stance"]
        self.first = attributes["first"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = second { attrs["second"] = v }
        if let v = stance { attrs["stance"] = v }
        if let v = first { attrs["first"] = v }
        return (attrs, [])
    }
}
