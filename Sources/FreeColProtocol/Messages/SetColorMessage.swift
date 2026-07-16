import Foundation

public struct SetColorMessage: FreeColMessage {
    public static let tag = "setColor"

    public let nation: String?
    public let color: String?

    public init(
        nation: String? = nil,
        color: String? = nil
    ) {
        self.nation = nation
        self.color = color
    }

    public init(attributes: Attributes, children: Children) throws {
        self.nation = attributes["nation"]
        self.color = attributes["color"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = nation { attrs["nation"] = v }
        if let v = color { attrs["color"] = v }
        return (attrs, [])
    }
}
