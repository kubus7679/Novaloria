import Foundation

public struct SetColorMessage: FreeColMessage {
    public static let tag = "setColor"

    public let color: String?
    public let nation: String?

    public init(
        color: String? = nil,
        nation: String? = nil
    ) {
        self.color = color
        self.nation = nation
    }

    public init(attributes: Attributes, children: Children) throws {
        self.color = attributes["color"]
        self.nation = attributes["nation"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = color { attrs["color"] = v }
        if let v = nation { attrs["nation"] = v }
        return (attrs, [])
    }
}
