import Foundation

public struct RenameMessage: FreeColMessage {
    public static let tag = "rename"

    public let name: String?
    public let nameable: String?

    public init(
        name: String? = nil,
        nameable: String? = nil
    ) {
        self.name = name
        self.nameable = nameable
    }

    public init(attributes: Attributes, children: Children) throws {
        self.name = attributes["name"]
        self.nameable = attributes["nameable"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = name { attrs["name"] = v }
        if let v = nameable { attrs["nameable"] = v }
        return (attrs, [])
    }
}
