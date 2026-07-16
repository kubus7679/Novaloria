import Foundation

public struct SetAvailableMessage: FreeColMessage {
    public static let tag = "setAvailable"

    public let state: String?
    public let nation: String?

    public init(
        state: String? = nil,
        nation: String? = nil
    ) {
        self.state = state
        self.nation = nation
    }

    public init(attributes: Attributes, children: Children) throws {
        self.state = attributes["state"]
        self.nation = attributes["nation"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = state { attrs["state"] = v }
        if let v = nation { attrs["nation"] = v }
        return (attrs, [])
    }
}
