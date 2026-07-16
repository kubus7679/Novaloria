import Foundation

public struct SetGoodsLevelsMessage: FreeColMessage {
    public static let tag = "setGoodsLevels"

    public let colony: String?
    public let children: [ParsedMessage]

    public init(
        colony: String? = nil
    ) {
        self.colony = colony
        self.children = []
    }

    public init(attributes: Attributes, children: Children) throws {
        self.colony = attributes["colony"]
        self.children = children.compactMap { dict in
            guard let tag = dict.keys.first else { return nil }
            return ParsedMessage(tag: tag, attributes: [:], children: [])
        }
    }

    public func encode() -> (attributes: Attributes, children: Children) {
        var attrs: Attributes = [:]
        if let v = colony { attrs["colony"] = v }
        return (attrs, [])
    }
}
