import Foundation

public struct RemoveMessage: FreeColMessage {
    public static let tag = "remove"

    public let divert: String?

    public init(
        divert: String? = nil
    ) {
        self.divert = divert
    }

    public init(attributes: Attributes, children: Children) throws {
        self.divert = attributes["divert"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = divert { attrs["divert"] = v }
        return (attrs, [])
    }
}
