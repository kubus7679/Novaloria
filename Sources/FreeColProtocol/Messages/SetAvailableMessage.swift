import Foundation

public struct SetAvailableMessage: FreeColMessage {
    public static let tag = "setAvailable"

    public let nation: String?
    public let state: String?

    public init(
        nation: String? = nil,
        state: String? = nil
    ) {
        self.nation = nation
        self.state = state
    }

    public init(attributes: Attributes, children: Children) throws {
        self.nation = attributes["nation"]
        self.state = attributes["state"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = nation { attrs["nation"] = v }
        if let v = state { attrs["state"] = v }
        return (attrs, [])
    }
}
