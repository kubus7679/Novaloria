import Foundation

public struct ChooseFoundingFatherMessage: FreeColMessage {
    public static let tag = "chooseFoundingFather"

    public let foundingFather: String?

    public init(
        foundingFather: String? = nil
    ) {
        self.foundingFather = foundingFather
    }

    public init(attributes: Attributes, children: Children) throws {
        self.foundingFather = attributes["foundingFather"]
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = foundingFather { attrs["foundingFather"] = v }
        return (attrs, [])
    }
}
